/*
===========================================================================
Copyright (C) 2015-2019 Project Meteor Dev Team

This file is part of Project Meteor Server.

Project Meteor Server is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Project Meteor Server is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with Project Meteor Server. If not, see <https:www.gnu.org/licenses/>.
===========================================================================
*/


using Meteor.Map.actors.director;
using Meteor.Map.Actors;
using Meteor.Map.DataObjects;
using Meteor.Map.packets.receive.events;
using Meteor.Map.packets.send;
using Meteor.Map.packets.send.events;
using System;
using System.Collections.Generic;
using System.IO;
using Meteor.Common;
using Meteor.Map.actors.area;
using System.Threading;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.controllers;
using Meteor.Map.actors.chara.player;
using Meteor.Map.Actors.Chara;
using Meteor.Map.DataObjects.chara;
using Meteor.Map.actors.chara;
using Meteor.Map.Actors.QuestNS;
using Meteor.Map.actors.group;
using static Meteor.Map.LuaUtils;

namespace Meteor.Map.lua
{
    class LuaEngine
    {
        public const string FILEPATH_PLAYER = "/Player.lua";
        public const string FILEPATH_ZONE = "/Unique/{0}/Zone.lua";
        public const string FILEPATH_CONTENT = "/Area/PrivateArea/Content/{0}.lua";
        public const string FILEPATH_COMMANDS = "/Command/{0}.lua";
        public const string FILEPATH_DIRECTORS = "/Director/{0}.lua";
        public const string FILEPATH_NPCS = "/Unique/{0}/{1}/{2}.lua";
        public const string FILEPATH_QUEST = "/Quest/{0}/{1}.lua";

        static readonly Dictionary<string, string> BattleCommandFolders = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["ability"] = "Ability", ["autoattack"] = "AutoAttack", ["magic"] = "Magic", ["weaponskill"] = "WeaponSkill",
        };

        // A DB name as its script's file name: power_surge_I is PowerSurgeI.
        public static string ScriptName(string name)
        {
            var sb = new System.Text.StringBuilder();
            foreach (var word in System.Text.RegularExpressions.Regex.Split(name ?? "", "[^A-Za-z0-9]+"))
                if (word.Length > 0)
                    sb.Append(char.ToUpperInvariant(word[0])).Append(word, 1, word.Length - 1);
            return sb.ToString();
        }

        static string BattleCommandPath(string folder, string name) =>
            $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Command/{(BattleCommandFolders.TryGetValue(folder, out var f) ? f : ScriptName(folder))}/{name}.lua";

        // A file in a scripts folder whatever its capitals, for names typed by players (GM commands).
        public static string FindScript(string folder, string name)
        {
            string dir = ConfigConstants.OPTIONS_SCRIPTPATH + folder;
            if (!Directory.Exists(dir))
                return null;
            foreach (var f in Directory.GetFiles(dir, "*.lua"))
                if (string.Equals(Path.GetFileNameWithoutExtension(f), name, StringComparison.OrdinalIgnoreCase))
                    return f;
            return null;
        }

        private static LuaEngine thisEngine;
        private Dictionary<LuaCoroutine, ulong> sleepingOnTime = new Dictionary<LuaCoroutine, ulong>();
        private Dictionary<string, List<LuaCoroutine>> sleepingOnSignal = new Dictionary<string, List<LuaCoroutine>>();
        private Dictionary<uint, LuaCoroutine> sleepingOnPlayerEvent = new Dictionary<uint, LuaCoroutine>();
        private Dictionary<LuaCoroutine, KeyValuePair<string, ulong>> signalDeadlines = new Dictionary<LuaCoroutine, KeyValuePair<string, ulong>>();
        private Dictionary<uint, KickWait> sleepingOnPlayerKick = new Dictionary<uint, KickWait>();

        private class KickWait
        {
            public LuaCoroutine coroutine;
            public uint ownerId;
            public string eventName;
        }
        // The three wait lists above are read by the timer thread and changed by the zone and network
        // threads, so they are only touched while holding this lock. Scripts are resumed after
        // letting go of it.
        private readonly object waitLock = new object();

        private Timer luaTimer;

        // The server functions every script can call by name.
        public static readonly IReadOnlyDictionary<string, Delegate> ScriptGlobals = new Dictionary<string, Delegate>
        {
            ["GetWorldManager"] = (Func<WorldManager>)Server.GetWorldManager,
            ["GetStaticActor"] = (Func<string, Actor>)Server.GetStaticActors,
            ["GetStaticActorById"] = (Func<uint, Actor>)Server.GetStaticActors,
            ["GetWorldMaster"] = (Func<Actor>)(() => Server.GetWorldManager().GetActor()),
            ["GetItemGamedata"] = (Func<uint, ItemData>)Server.GetItemGamedata,
            ["GetGuildleveGamedata"] = (Func<uint, GuildleveData>)Server.GetGuildleveGamedata,
            ["GetMateriaGamedata"] = (Func<int, MateriaData>)Server.GetMateriaGamedata,
            ["GetLuaInstance"] = (Func<LuaEngine>)LuaEngine.GetInstance,
            ["GetPassiveGLGamedata"] = (Func<uint, PassiveGuildleveData>)Server.GetPassiveGLGamedata,
            ["GetRecipeResolver"] = (Func<RecipeResolver>)Server.ResolveRecipe,
            ["StartContent"] = (Func<string, string, Area, Player, XLua.LuaTable, Meteor.Map.Content.Encounter>)Meteor.Map.Content.ContentManager.Start,
            ["GetContentFor"] = (Func<Player, Meteor.Map.Content.Encounter>)Meteor.Map.Content.ContentManager.ForPlayer,
            ["DescribeContent"] = (Func<string>)Meteor.Map.Content.ContentManager.Describe,
            ["DescribeAi"] = (Func<Character, string>)(c => c?.Brain?.Describe() ?? "no brain"),
        };

        private LuaEngine()
        {
            luaTimer = new Timer(new TimerCallback(PulseSleepingOnTime),
                           null, TimeSpan.Zero, TimeSpan.FromMilliseconds(50));
        }

        public static LuaEngine GetInstance()
        {
            if (thisEngine == null)
                thisEngine = new LuaEngine();

            return thisEngine;
        }

        public void AddWaitCoroutine(LuaCoroutine coroutine, float seconds)
        {
            ulong time = Utils.MilisUnixTimeStampUTC() + (ulong)(seconds * 1000);
            lock (waitLock)
                sleepingOnTime.Add(coroutine, time);
        }

        public void AddWaitSignalCoroutine(LuaCoroutine coroutine, string signal, float timeoutSeconds = 0)
        {
            lock (waitLock)
            {
                if (!sleepingOnSignal.ContainsKey(signal))
                    sleepingOnSignal.Add(signal, new List<LuaCoroutine>());
                sleepingOnSignal[signal].Add(coroutine);
                if (timeoutSeconds > 0)
                    signalDeadlines[coroutine] = new KeyValuePair<string, ulong>(signal, Utils.MilisUnixTimeStampUTC() + (ulong)(timeoutSeconds * 1000));
            }
        }

        // Drops this player's event waits when the session ends; otherwise the next login's first event
        // would resume the old script with the old Player.
        public void CancelPlayerEvent(Player player)
        {
            if (player == null)
                return;
            lock (waitLock)
            {
                sleepingOnPlayerEvent.Remove(player.Id);
                sleepingOnPlayerKick.Remove(player.Id);
            }
        }

        public void AddWaitKickCoroutine(Player player, LuaCoroutine coroutine, uint ownerId, string eventName)
        {
            lock (waitLock)
            {
                if (!sleepingOnPlayerKick.ContainsKey(player.Id))
                    sleepingOnPlayerKick.Add(player.Id, new KickWait { coroutine = coroutine, ownerId = ownerId, eventName = eventName ?? "" });
            }
        }

        private void PulseSignalTimeouts(ulong currentTime)
        {
            List<LuaCoroutine> expired = new List<LuaCoroutine>();
            lock (waitLock)
            {
                foreach (var entry in signalDeadlines)
                {
                    if (entry.Value.Value > currentTime)
                        continue;
                    expired.Add(entry.Key);
                    if (sleepingOnSignal.TryGetValue(entry.Value.Key, out var waiters))
                    {
                        waiters.Remove(entry.Key);
                        if (waiters.Count == 0)
                            sleepingOnSignal.Remove(entry.Value.Key);
                    }
                }
                foreach (LuaCoroutine key in expired)
                    signalDeadlines.Remove(key);
            }

            foreach (LuaCoroutine key in expired)
                ResumeLogged(null, key);
        }

        public void AddWaitEventCoroutine(Player player, LuaCoroutine coroutine)
        {
            lock (waitLock)
            {
                if (!sleepingOnPlayerEvent.ContainsKey(player.Id))
                    sleepingOnPlayerEvent.Add(player.Id, coroutine);
            }
        }

        // Takes the script that is waiting for this player's next reply, if there is one.
        private LuaCoroutine TakeEventWait(Player player)
        {
            lock (waitLock)
            {
                LuaCoroutine coroutine;
                if (sleepingOnPlayerEvent.TryGetValue(player.Id, out coroutine))
                    sleepingOnPlayerEvent.Remove(player.Id);
                return coroutine;
            }
        }

        private LuaCoroutine TakeUpdateWait(Player player)
        {
            LuaCoroutine coroutine = TakeEventWait(player);
            if (coroutine != null)
                return coroutine;
            lock (waitLock)
            {
                if (sleepingOnPlayerKick.TryGetValue(player.Id, out KickWait kick))
                {
                    sleepingOnPlayerKick.Remove(player.Id);
                    return kick.coroutine;
                }
            }
            return null;
        }

        private LuaCoroutine TakeStartWait(Player player, EventStartPacket eventStart)
        {
            lock (waitLock)
            {
                if (sleepingOnPlayerKick.TryGetValue(player.Id, out KickWait kick))
                {
                    if (kick.ownerId == eventStart.ownerActorID && kick.eventName.Equals(eventStart.eventName))
                    {
                        sleepingOnPlayerKick.Remove(player.Id);
                        return kick.coroutine;
                    }
                    Program.Log.Debug("LuaEngine: EventStart {0:X}/{1} is not the kicked {2:X}/{3}; running it as a new event.",
                        eventStart.ownerActorID, eventStart.eventName, kick.ownerId, kick.eventName);
                }
            }
            return TakeEventWait(player);
        }

        public void PulseSleepingOnTime(object state)
        {
            ulong currentTime = Utils.MilisUnixTimeStampUTC();
            List<LuaCoroutine> toAwake = new List<LuaCoroutine>();

            lock (waitLock)
            {
                foreach (KeyValuePair<LuaCoroutine, ulong> entry in sleepingOnTime)
                {
                    if (entry.Value <= currentTime)
                        toAwake.Add(entry.Key);
                }
                foreach (LuaCoroutine key in toAwake)
                    sleepingOnTime.Remove(key);
            }

            foreach (LuaCoroutine key in toAwake)
                ResumeLogged(null, key);

            PulseSignalTimeouts(currentTime);

            (ScriptEngine.Instance as XLuaEngine)?.Tick();
        }

        // Carries on a script whose wait is over. A script error is only logged here,
        // because an error escaping the timer thread would shut down the server.
        private void ResumeLogged(Player player, LuaCoroutine coroutine, params object[] args)
        {
            try
            {
                ResolveResume(player, coroutine, coroutine.Resume(args));
            }
            catch (LuaScriptException e)
            {
                LuaScript.Log.Error(e.DecoratedMessage);
            }
        }

        public void OnSignal(string signal, params object[] args)
        {
            List<LuaCoroutine> toAwake = new List<LuaCoroutine>();

            lock (waitLock)
            {
                if (sleepingOnSignal.ContainsKey(signal))
                {
                    toAwake.AddRange(sleepingOnSignal[signal]);
                    sleepingOnSignal.Remove(signal);
                }
                foreach (LuaCoroutine key in toAwake)
                    signalDeadlines.Remove(key);
            }

            foreach (LuaCoroutine key in toAwake)
                ResumeLogged(null, key, args.Length == 0 ? new object[] { true } : args);
        }

        public void OnEventUpdate(Player player, List<LuaParam> args)
        {
            LuaCoroutine coroutine = TakeUpdateWait(player);
            if (coroutine != null)
            {
                try
                {
                    ResolveResume(player, coroutine, coroutine.Resume(LuaUtils.CreateLuaParamObjectList(args)));
                }
                catch (LuaScriptException e)
                {
                    LuaEngine.SendError(player, String.Format("OnEventUpdated: {0}", e.DecoratedMessage));
                    player.EndEvent();
                }
            }
            else
                player.EndEvent();
        }

        // Battle hooks in Player.lua. Npcs get theirs through the AI runtime (Ai/Runtime).
        public static bool CallLuaPlayerFunction(Player player, string functionName, params object[] args)
        {
            return CallLuaScriptFileFunction(ConfigConstants.OPTIONS_SCRIPTPATH + FILEPATH_PLAYER, functionName, args);
        }

        public const string FILEPATH_BATTLENPC_STATS = "/BattleNpcStats.lua";

        // True if the file and function exist and it ran without error.
        public static bool CallLuaScriptFileFunction(string path, string functionName, params object[] args)
        {
            if (!File.Exists(path))
                return false;
            var script = ScriptEngine.Instance.Load(path);
            if (script == null || !script.HasFunction(functionName))
                return false;
            return script.Call(functionName, args) != null;
        }

        // defaultValue when the call fails or doesn't return a number.
        public static int CallLuaScriptFileFunctionForInt(string path, string functionName, int defaultValue, params object[] args)
        {
            if (!File.Exists(path))
                return defaultValue;
            var script = ScriptEngine.Instance.Load(path);
            if (script == null || !script.HasFunction(functionName))
                return defaultValue;
            object[] result = script.Call(functionName, args);
            return result != null && result.Length > 0 && result[0] is double d ? (int)d : defaultValue;
        }

        // Calls a function in a module script, e.g. "items.use". True when it ran.
        public static bool CallLuaModuleFunction(string path, string functionName, params object[] args)
        {
            if (!File.Exists(path))
                return false;
            var script = ScriptEngine.Instance.Load(path);
            if (script == null || !script.HasFunction(functionName))
                return false;
            return script.Call(functionName, args) != null;
        }

        public static int CallLuaStatusEffectFunction(Character actor, StatusEffect effect, string functionName, params object[] args)
        {
            // todo: this is stupid, load the actual effect name from db table
            string path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Status/{ScriptName(effect.GetName())}.lua";

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                int? res = CallForResult(script, functionName, args);
                if (res != null)
                    return res.Value;
            }
            else
            {
                Program.Log.Error($"LuaEngine.CallLuaStatusEffectFunction [{effect.GetName()}] Unable to find script {path}");
            }
            return -1;
        }

        public static int CallLuaBattleCommandFunction(Character actor, BattleCommand command, string folder, string functionName, params object[] args)
        {
            string path = BattleCommandPath(folder, ScriptName(command.name));

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                int? res = CallForResult(script, functionName, args);
                if (res != null)
                    return res.Value;
            }
            else
            {
                path = BattleCommandPath(folder, "Default");
                //Program.Log.Error($"LuaEngine.CallLuaBattleCommandFunction [{command.name}] Unable to find script {path}");
                var script = ScriptEngine.Instance.Load(path);
                int? res = CallForResult(script, functionName, args);
                if (res != null)
                    return res.Value;
            }
            return -1;
        }


        public static void LoadBattleCommandScript(BattleCommand command, string folder)
        {
            string path = BattleCommandPath(folder, ScriptName(command.name));

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                command.script = script;
            }
            else
            {
                path = BattleCommandPath(folder, "Default");
                //Program.Log.Error($"LuaEngine.CallLuaBattleCommandFunction [{command.name}] Unable to find script {path}");
                var script = ScriptEngine.Instance.Load(path);

                command.script = script;
            }
        }

        public static void LoadStatusEffectScript(StatusEffect effect)
        {
            string path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Status/{ScriptName(effect.GetName())}.lua";

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                effect.script = script;
            }
            else
            {
                path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Status/Default.lua";
                //Program.Log.Error($"LuaEngine.CallLuaBattleCommandFunction [{command.name}] Unable to find script {path}");
                var script = ScriptEngine.Instance.Load(path);

                effect.script = script;
            }
        }


        public bool ScriptDefinesFunction(Actor target, string funcName)
        {
            string path = GetScriptPath(target);
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
                return false;
            var script = ScriptEngine.Instance.Load(path);
            return script != null && script.HasFunction(funcName);
        }

        public static string GetScriptPath(Actor target)
        {
            string root = ConfigConstants.OPTIONS_SCRIPTPATH;
            if (target is Player)
            {
                return root + FILEPATH_PLAYER;
            }
            else if (target is Npc)
            {
                return null;
            }
            else if (target is Command)
            {                
                return root + String.Format(FILEPATH_COMMANDS, target.GetName());
            }
            else if (target is Director)
            {
                return root + String.Format(FILEPATH_DIRECTORS, ((Director)target).GetScriptPath());
            }
            else if (target is PrivateAreaContent)
            {
                return root + String.Format(FILEPATH_CONTENT, ((PrivateAreaContent)target).GetPrivateAreaName());
            }
            else if (target is Area)
            {
                return root + String.Format(FILEPATH_ZONE, ((Area)target).ZoneName);
            }
            else if (target is Quest)
            {
                string questName = ((Quest)target).Name;
                string initial = questName.Substring(0, 3);
                return root + String.Format(FILEPATH_QUEST, initial, questName);
            }
            else
                return "";
        }

        // The npc's class script. A monster class without one uses Chara/Npc/Monster/Monster.lua, so
        // it still binds as a monster instead of a static townsperson.
        private static string NpcClassScriptPath(Npc target)
        {
            string path = ConfigConstants.OPTIONS_SCRIPTPATH + target.ScriptClassPath + ".lua";
            if (File.Exists(path))
                return path;
            if (target.ScriptClassPath != null && target.ScriptClassPath.StartsWith(MONSTER_CLASS_ROOT, StringComparison.Ordinal))
            {
                string fallback = ConfigConstants.OPTIONS_SCRIPTPATH + MONSTER_CLASS_ROOT + "Monster.lua";
                if (File.Exists(fallback))
                    return fallback;
            }
            return null;
        }

        private const string MONSTER_CLASS_ROOT = "/Chara/Npc/Monster/";

        private List<LuaParam> CallLuaFunctionNpcForReturn(Player player, Npc target, string funcName, bool optional, params object[] args)
        {
            object[] args2 = new object[args.Length + (player == null ? 1 : 2)];
            Array.Copy(args, 0, args2, (player == null ? 1 : 2), args.Length);
            if (player != null)
            {
                args2[0] = player;
                args2[1] = target;
            }
            else
                args2[0] = target;

            LuaScript parent = null, child = null;
            string errorMsg = "";

            string classScript = NpcClassScriptPath(target);
            if (classScript != null)
                parent = LuaEngine.LoadScript(classScript, ref errorMsg);

            if (!errorMsg.Equals(""))
                SendError(player, errorMsg);

            Area area = target.CurrentArea;
            if (area is PrivateArea)
            {
                string path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{area.ZoneName}/PrivateArea/{((PrivateArea)area).GetPrivateAreaName()}_{((PrivateArea)area).GetPrivateAreaType()}/{target.className}/{target.GetUniqueId()}.lua";
                if (File.Exists(path))
                    child = LuaEngine.LoadScript(path, ref errorMsg);
            }
            else
            {
                string path = $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{area.ZoneName}/{target.className}/{target.GetUniqueId()}.lua";
                if (File.Exists(path))
                    child = LuaEngine.LoadScript(path, ref errorMsg);
            }

            if (parent == null && child == null)
            {
                LuaEngine.SendError(player, $"ERROR: Could not find script for actor {target.GetName()}.");
            }

            //Run Script
            object[] result;

            if (child != null && child.GetGlobal(funcName) != null)
                result = child.Call(funcName, args2);
            else if (parent != null && parent.GetGlobal(funcName) != null)
                result = parent.Call(funcName, args2);
            else
                return null;

            List<LuaParam> lparams = LuaUtils.CreateLuaParamListFromScript(result);
            return lparams;
        }

        private void CallLuaFunctionNpc(Player player, Npc target, string funcName, bool optional, params object[] args)
        {
            object[] args2 = new object[args.Length + (player == null ? 1 : 2)];
            Array.Copy(args, 0, args2, (player == null ? 1 : 2), args.Length);
            if (player != null)
            {
                args2[0] = player;
                args2[1] = target;
            }
            else
                args2[0] = target;

            LuaScript parent = null, child = null;
            string errorMsg = "";

            string classScript = NpcClassScriptPath(target);
            if (classScript != null)
                parent = LuaEngine.LoadScript(classScript, ref errorMsg);

            Area area = target.CurrentArea;
            if (area is PrivateArea)
            {
                if (File.Exists(String.Format($"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{0}/PrivateArea/{1}_{2}/{3}/{4}.lua", area.ZoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format($"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{0}/PrivateArea/{1}_{2}/{3}/{4}.lua", area.ZoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId()), ref errorMsg);
            }
            else
            {
                if (File.Exists(String.Format($"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{0}/{1}/{2}.lua", area.ZoneName, target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format($"{ConfigConstants.OPTIONS_SCRIPTPATH}/Unique/{0}/{1}/{2}.lua", area.ZoneName, target.className, target.GetUniqueId()), ref errorMsg);
            }

            if (parent == null && child == null)
            {
                LuaEngine.SendError(player, String.Format("Could not find script for actor {0}.", target.GetName()));
                return;
            }

            //Run Script
            LuaCoroutine coroutine = null;

            if (child != null && child.GetGlobal(funcName) != null)
                coroutine = child.CreateCoroutine(funcName);
            else if (parent != null && parent.GetGlobal(funcName) != null)
                coroutine = parent.CreateCoroutine(funcName);

            if (coroutine != null)
            {
                try
                {
                    ResolveResume(player, coroutine, coroutine.Resume(args2));
                }
                catch (LuaScriptException e)
                {
                    SendError(player, e.DecoratedMessage);
                }
            }
            if (!errorMsg.Equals(""))
                SendError(player, errorMsg);
        }

        public List<LuaParam> CallLuaFunctionForReturn(Player player, Actor target, string funcName, bool optional, params object[] args)
        {
            //Need a seperate case for NPCs cause that child/parent thing.
            if (target is Npc)
                return CallLuaFunctionNpcForReturn(player, (Npc)target, funcName, optional, args);

            object[] args2 = new object[args.Length + (player == null ? 1 : 2)];
            Array.Copy(args, 0, args2, (player == null ? 1 : 2), args.Length);
            if (player != null)
            {
                args2[0] = player;
                args2[1] = target;
            }
            else
                args2[0] = target;

            string errorMsg = "";

            string luaPath = GetScriptPath(target);
            LuaScript script = LoadScript(luaPath, ref errorMsg);
            if (script != null)
            {
                if (script.GetGlobal(funcName) != null)
                {
                    //Run Script
                    object[] result = script.Call(funcName, args2);
                    List<LuaParam> lparams = LuaUtils.CreateLuaParamListFromScript(result);
                    return lparams;
                }
                else
                {
                    if (!optional)
                        SendError(player, String.Format("Could not find function '{0}' for actor {1}.", funcName, target.GetName()));
                }
            }
            else
            {
                if (!optional)
                    SendError(player, String.Format("Could not find script for actor {0}.", target.GetName()));
            }
            if (!errorMsg.Equals(""))
                SendError(player, errorMsg);
            return null;
        }

        public List<LuaParam> CallLuaFunctionForReturn(string path, string funcName, bool optional, params object[] args)
        {
            string luaPath = path;
            string errorMsg = "";
            LuaScript script = LoadScript(luaPath, ref errorMsg);
            if (script != null)
            {
                if (script.GetGlobal(funcName) != null)
                {
                    //Run Script
                    object[] result = script.Call(funcName, args);
                    List<LuaParam> lparams = LuaUtils.CreateLuaParamListFromScript(result);
                    return lparams;
                }
            }           
            return null;
        }

        public void CallLuaFunction(Player player, Actor target, string funcName, bool optional, params object[] args)
        {
            //Need a seperate case for NPCs cause that child/parent thing.
            if (target is Npc)
            {
                CallLuaFunctionNpc(player, (Npc)target, funcName, optional, args);
                return;
            }

            object[] args2 = new object[args.Length + 2];
            Array.Copy(args, 0, args2, 2, args.Length);
            args2[0] = player;
            args2[1] = target;

            string errorMsg = "";
            string luaPath = GetScriptPath(target);
            LuaScript script = LoadScript(luaPath, ref errorMsg);
            if (script != null)
            {
                if (script.GetGlobal(funcName) != null)
                {
                    try
                    {
                        LuaCoroutine coroutine = script.CreateCoroutine(funcName);
                        ResolveResume(player, coroutine, coroutine.Resume(args2));
                    }
                    catch(Exception e)
                    {
                        player.SendMessage(0x20, "", e.Message);
                        player.EndEvent();

                    }
                }
                else
                {
                    if (!optional)
                        SendError(player, String.Format("Could not find function '{0}' for actor {1}.", funcName, target.GetName()));
                }
            }
            else
            {
                if (!(target is Area) && !optional)
                    SendError(player, String.Format("Could not find script for actor {0}.", target.GetName()));
            }
            if (!errorMsg.Equals(""))
                SendError(player, errorMsg);
        }

        public void EventStarted(Player player, Actor target, EventStartPacket eventStart)
        {
            if (eventStart.luaParams == null)
                return;

            List<LuaParam> lparams = new List<LuaParam>();
            lparams.AddRange(eventStart.luaParams);
            lparams.Insert(0, new LuaParam(0, eventStart.eventType));
            lparams.Insert(1, new LuaParam(2, eventStart.eventName));
            // Talking to a battle npc whose profile listens for it (a caravan chocobo, a guard).
            if (target is Character chara && chara.Brain != null && chara.Brain.HasHook("onTalked"))
            {
                player.EndEvent();
                Meteor.Map.AI.EventBus.Raise(Meteor.Map.AI.ActorEventType.Talked, chara, player);
                return;
            }
            LuaCoroutine coroutine = TakeStartWait(player, eventStart);
            Program.Log.Debug("LuaEngine: EventStart {0:X}/{1} type {2}: {3}.", eventStart.ownerActorID, eventStart.eventName, eventStart.eventType,
                coroutine != null ? "resumes a waiting script" : "runs onEventStarted on " + (target?.GetName() ?? "null"));
            if (coroutine != null)
            {
                try
                {
                    ResolveResume(null, coroutine, coroutine.Resume());
                }
                catch (LuaScriptException e)
                {
                    LuaEngine.SendError(player, String.Format("OnEventStarted: {0}", e.DecoratedMessage));
                    player.EndEvent();
                }
            }
            else
            {
                if (target is Director)
                    ((Director)target).OnEventStart(player, LuaUtils.CreateLuaParamObjectList(lparams));
                else
                    CallLuaFunction(player, target, "onEventStarted", false, LuaUtils.CreateLuaParamObjectList(lparams));
            }
        }

        // When a script paused to wait (wait, waitForSignal, callClientFunction or kickEvent
        // in global.lua), puts it on the matching wait list so it carries on at the right time.
        public LuaResume ResolveResume(Player player, LuaCoroutine coroutine, LuaResume value)
        {
            if (value == null || !value.Yielded || value.Count == 0 || !(value[0] is string tag))
                return value;

            if (value.Count == 1)
            {
                if (player != null && tag == "_WAIT_EVENT")
                    GetInstance().AddWaitEventCoroutine(player, coroutine);
                return value;
            }

            switch (tag)
            {
                case "_WAIT_TIME":
                    GetInstance().AddWaitCoroutine(coroutine, (float)(value[1] is double seconds ? seconds : 0));
                    break;
                case "_WAIT_SIGNAL":
                    float timeout = value.Count >= 3 && value[2] is IConvertible t ? Convert.ToSingle(t) : 0;
                    GetInstance().AddWaitSignalCoroutine(coroutine, value[1] as string, timeout);
                    break;
                case "_WAIT_EVENT":
                    if (value.Count >= 4 && value[2] is IConvertible owner && value[3] is string eventName)
                        GetInstance().AddWaitKickCoroutine((Player)value[1], coroutine, Convert.ToUInt32(owner), eventName);
                    else
                        GetInstance().AddWaitEventCoroutine((Player)value[1], coroutine);
                    break;
            }
            return value;
        }

        #region RunGMCommand
        public static void RunGMCommand(Player player, String cmd, string[] param, bool help = false)
        {
            bool playerNull = player == null;

            if (playerNull && param != null) // param is null for console !help
            {
                if (param.Length >= 2 && param[1].Contains("\""))
                    player = Server.GetWorldManager().GetPCInWorld(param[1]);
                else if (param.Length > 2)
                    player = Server.GetWorldManager().GetPCInWorld(param[1] + param[2]);
            }

            if (playerNull && param != null && param.Length >= 3)
                player = Server.GetWorldManager().GetPCInWorld(param[1] + " " + param[2]);

            var path = FindScript("/Command/Gm", cmd) ?? $"{ConfigConstants.OPTIONS_SCRIPTPATH}/Command/Gm/{cmd}.lua";

            // check if the file exists
            if (File.Exists(path))
            {
                LuaScript script = ScriptEngine.Instance.Load(path);

                // can we run this script
                if (script.GetGlobal("onTrigger") != null)
                {
                    // can i run this command
                    var permissions = 0;

                    // parameter types (string, integer, double, float)
                    var parameters = "";
                    var description = "!" + cmd + ": ";

                    // get the properties table
                    var res = script.GetGlobal("properties");

                    // make sure properties table exists
                    if (res != null)
                    {
                        try
                        {
                            var table = (LuaTableValue)res;

                            // find each key/value pair
                            foreach (var pair in table.Pairs)
                            {
                                if (pair.Key as string == "permissions")
                                {
                                    permissions = pair.Value is double p ? (int)p : 0;
                                }
                                else if (pair.Key as string == "parameters")
                                {
                                    parameters = pair.Value as string;
                                }
                                else if (pair.Key as string == "description")
                                {
                                    description = pair.Value as string;
                                }
                            }
                        }
                        catch (Exception e) { LuaScript.Log.Error("LuaEngine.RunGMCommand: " + e.Message); return; }
                    }

                    if (!playerNull)
                    {
                        if (player.gmLevel < permissions)
                        {
                            if (!help)
                            {
                                Program.Log.Info("LuaEngine.RunGMCommand: {0}'s GM level is too low to use command {1}.", player.Name, cmd);
                                player.SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM_ERROR, "", String.Format("You do not have permission to use !{0}.", cmd));
                            }
                            return;
                        }
                        // i hate to do this, but cant think of a better way to keep !help
                        else if (help)
                        {
                            player.SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM_ERROR, String.Format("[Commands] [{0}]", cmd), description);
                            return;
                        }
                    }
                    else if (help)
                    {
                        LuaScript.Log.Info("[Commands] [{0}]: {1}", cmd, description);
                        return;
                    }

                    // we'll push our lua params here
                    List<object> LuaParam = new List<object>();

                    var i = playerNull ? 2 : 0;
                    for (; i < parameters.Length; ++i)
                    {
                        try
                        {
                            // convert chat parameters to command parameters
                            switch (parameters[i])
                            {
                                case 'i':
                                    LuaParam.Add(Convert.ChangeType(param[i + 1], typeof(int)));
                                    continue;
                                case 'd':
                                    LuaParam.Add(Convert.ChangeType(param[i + 1], typeof(double)));
                                    continue;
                                case 'f':
                                    LuaParam.Add(Convert.ChangeType(param[i + 1], typeof(float)));
                                    continue;
                                case 's':
                                    LuaParam.Add(param[i + 1]);
                                    continue;
                                default:
                                    LuaScript.Log.Info("LuaEngine.RunGMCommand: {0} unknown parameter {1}.", path, parameters[i]);
                                    LuaParam.Add(param[i + 1]);
                                    continue;
                            }
                        }
                        catch (Exception e)
                        {
                            if (e is IndexOutOfRangeException) break;
                            LuaParam.Add(param[i + 1]);
                        }
                    }

                    // the script can double check the player exists, we'll push them anyways
                    LuaParam.Insert(0, player);
                    // push the arg count too
                    LuaParam.Insert(1, i - (playerNull ? 2 : 0));

                    // run the script                    
                    //script.Call(script.Globals["onTrigger"], LuaParam.ToArray());

                    // gm commands dont need to be coroutines?
                    try
                    {
                        LuaCoroutine coroutine = script.CreateCoroutine("onTrigger");
                        GetInstance().ResolveResume(player, coroutine, coroutine.Resume(LuaParam.ToArray()));
                    }
                    catch (Exception e)
                    {
                        Program.Log.Error("LuaEngine.RunGMCommand: {0} - {1}", path, e.Message);
                    }
                    return;
                }
            }
            LuaScript.Log.Error("LuaEngine.RunGMCommand: Unable to find script {0}", path);
            return;
        }
        #endregion
        
        public bool ScriptDeclares(Actor target, string globalName)
        {
            string errorMsg = "";
            string path = GetScriptPath(target);
            if (string.IsNullOrEmpty(path))
                return false;
            object value = LoadScript(path, ref errorMsg)?.GetGlobal(globalName);
            return value != null && !(value is bool b && !b);
        }

        public static LuaScript LoadScript(string path, ref string errorMsg)
        {
            return ScriptEngine.Instance.Load(path);
        }

        // Calls a battle or status-effect script function and returns the number it returned
        // (0 if it returned none). Null when the script has no such function or the call failed.
        private static int? CallForResult(LuaScript script, string functionName, object[] args)
        {
            if (script == null || !script.HasFunction(functionName))
                return null;
            object[] res = script.Call(functionName, args);
            if (res == null)
                return null;
            return res.Length > 0 && res[0] is double d ? (int)d : 0;
        }

        public static void SendError(Player player, string message)
        {
            message = "[LuaError] " + message;
            if (player == null)
                return;
            List<SubPacket> SendError = new List<SubPacket>();
            player.SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM_ERROR, "", message);
            player.QueuePacket(EndEventPacket.BuildPacket(player.Id, player.currentEventOwner, player.currentEventName, 0));
        }

    }
}
