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
using Meteor.Map.dataobjects;
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
using Meteor.Map.DataObjects;

namespace Meteor.Map.lua
{
    class LuaEngine
    {
        public const string FILEPATH_PLAYER = "./scripts/player.lua";
        public const string FILEPATH_ZONE = "./scripts/unique/{0}/zone.lua";
        public const string FILEPATH_CONTENT = "./scripts/content/{0}.lua";
        public const string FILEPATH_COMMANDS = "./scripts/commands/{0}.lua";
        public const string FILEPATH_DIRECTORS = "./scripts/directors/{0}.lua";
        public const string FILEPATH_NPCS = "./scripts/unique/{0}/{1}/{2}.lua";
        public const string FILEPATH_QUEST = "./scripts/quests/{0}/{1}.lua";

        private static LuaEngine mThisEngine;
        private Dictionary<LuaCoroutine, ulong> mSleepingOnTime = new Dictionary<LuaCoroutine, ulong>();
        private Dictionary<string, List<LuaCoroutine>> mSleepingOnSignal = new Dictionary<string, List<LuaCoroutine>>();
        private Dictionary<uint, LuaCoroutine> mSleepingOnPlayerEvent = new Dictionary<uint, LuaCoroutine>();
        // Guards the three wait tables: the timer thread pulses them while zone and network threads
        // add and take waits. Coroutines are resumed outside it.
        private readonly object waitLock = new object();

        private Timer luaTimer;

        /// <summary>The functions every script sees as globals.</summary>
        public static readonly IReadOnlyDictionary<string, Delegate> ScriptGlobals = new Dictionary<string, Delegate>
        {
            ["GetWorldManager"] = (Func<WorldManager>)Server.GetWorldManager,
            ["GetStaticActor"] = (Func<string, Actor>)Server.GetStaticActors,
            ["GetStaticActorById"] = (Func<uint, Actor>)Server.GetStaticActors,
            ["GetWorldMaster"] = (Func<Actor>)(() => Server.GetWorldManager().GetActor()),
            ["GetItemGamedata"] = (Func<uint, ItemData>)Server.GetItemGamedata,
            ["GetGuildleveGamedata"] = (Func<uint, GuildleveData>)Server.GetGuildleveGamedata,
            ["GetLuaInstance"] = (Func<LuaEngine>)LuaEngine.GetInstance,
        };

        private LuaEngine()
        {
            luaTimer = new Timer(new TimerCallback(PulseSleepingOnTime),
                           null, TimeSpan.Zero, TimeSpan.FromMilliseconds(50));
        }

        public static LuaEngine GetInstance()
        {
            if (mThisEngine == null)
                mThisEngine = new LuaEngine();

            return mThisEngine;
        }

        public void AddWaitCoroutine(LuaCoroutine coroutine, float seconds)
        {
            ulong time = Utils.MilisUnixTimeStampUTC() + (ulong)(seconds * 1000);
            lock (waitLock)
                mSleepingOnTime.Add(coroutine, time);
        }

        public void AddWaitSignalCoroutine(LuaCoroutine coroutine, string signal)
        {
            lock (waitLock)
            {
                if (!mSleepingOnSignal.ContainsKey(signal))
                    mSleepingOnSignal.Add(signal, new List<LuaCoroutine>());
                mSleepingOnSignal[signal].Add(coroutine);
            }
        }

        public void AddWaitEventCoroutine(Player player, LuaCoroutine coroutine)
        {
            lock (waitLock)
            {
                if (!mSleepingOnPlayerEvent.ContainsKey(player.actorId))
                    mSleepingOnPlayerEvent.Add(player.actorId, coroutine);
            }
        }

        /// <summary>Removes and returns the coroutine waiting on the player's next event packet.</summary>
        private LuaCoroutine TakeEventWait(Player player)
        {
            lock (waitLock)
            {
                LuaCoroutine coroutine;
                if (mSleepingOnPlayerEvent.TryGetValue(player.actorId, out coroutine))
                    mSleepingOnPlayerEvent.Remove(player.actorId);
                return coroutine;
            }
        }

        public void PulseSleepingOnTime(object state)
        {
            ulong currentTime = Utils.MilisUnixTimeStampUTC();
            List<LuaCoroutine> mToAwake = new List<LuaCoroutine>();

            lock (waitLock)
            {
                foreach (KeyValuePair<LuaCoroutine, ulong> entry in mSleepingOnTime)
                {
                    if (entry.Value <= currentTime)
                        mToAwake.Add(entry.Key);
                }
                foreach (LuaCoroutine key in mToAwake)
                    mSleepingOnTime.Remove(key);
            }

            foreach (LuaCoroutine key in mToAwake)
                ResumeLogged(null, key);

            (ScriptEngine.Instance as XLuaEngine)?.Tick();
        }

        /// <summary>Resumes a waiting coroutine from the timer or a signal. A script error is logged:
        /// an exception escaping the timer thread would end the process.</summary>
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
            List<LuaCoroutine> mToAwake = new List<LuaCoroutine>();

            lock (waitLock)
            {
                if (mSleepingOnSignal.ContainsKey(signal))
                {
                    mToAwake.AddRange(mSleepingOnSignal[signal]);
                    mSleepingOnSignal.Remove(signal);
                }
            }

            foreach (LuaCoroutine key in mToAwake)
                ResumeLogged(null, key, args);
        }

        public void OnEventUpdate(Player player, List<LuaParam> args)
        {
            LuaCoroutine coroutine = TakeEventWait(player);
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

        /// <summary> 
        /// // todo: this is dumb, should probably make a function for each action with different default return values
        /// or just make generic function and pass default value as first arg after functionName
        /// </summary>
        public static void CallLuaBattleFunction(Character actor, string functionName, params object[] args)
        {
            // todo: should use "scripts/zones/ZONE_NAME/battlenpcs/NAME.lua" instead of scripts/unique
            string path = "";

            // todo: should we call this for players too?
            if (actor is Player)
            {
                // todo: check this is correct
                path = FILEPATH_PLAYER;
            }
            else if (actor is Npc)
            {
                // todo: this is probably unnecessary as im not sure there were pets for players
                if (!(actor.aiContainer.GetController<PetController>()?.GetPetMaster() is Player))
                    path = String.Format("./scripts/unique/{0}/{1}/{2}.lua", actor.zone.zoneName, actor is BattleNpc ? "Monster" : "PopulaceStandard", ((Npc)actor).GetUniqueId());
            }
            // dont wanna throw an error if file doesnt exist
            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                if (script.HasFunction(functionName))
                    script.Call(functionName, args);
            }
        }

        public static int CallLuaStatusEffectFunction(Character actor, StatusEffect effect, string functionName, params object[] args)
        {
            // todo: this is stupid, load the actual effect name from db table
            string path = $"./scripts/effects/{effect.GetName()}.lua";

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
            string path = $"./scripts/commands/{folder}/{command.name}.lua";

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                int? res = CallForResult(script, functionName, args);
                if (res != null)
                    return res.Value;
            }
            else
            {
                path = $"./scripts/commands/{folder}/default.lua";
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
            string path = $"./scripts/commands/{folder}/{command.name}.lua";

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                command.script = script;
            }
            else
            {
                path = $"./scripts/commands/{folder}/default.lua";
                //Program.Log.Error($"LuaEngine.CallLuaBattleCommandFunction [{command.name}] Unable to find script {path}");
                var script = ScriptEngine.Instance.Load(path);

                command.script = script;
            }
        }

        public static void LoadStatusEffectScript(StatusEffect effect)
        {
            string path = $"./scripts/effects/{effect.GetName()}.lua";

            if (File.Exists(path))
            {
                var script = ScriptEngine.Instance.Load(path);
                effect.script = script;
            }
            else
            {
                path = $"./scripts/effects/default.lua";
                //Program.Log.Error($"LuaEngine.CallLuaBattleCommandFunction [{command.name}] Unable to find script {path}");
                var script = ScriptEngine.Instance.Load(path);

                effect.script = script;
            }
        }


        public static string GetScriptPath(Actor target)
        {
            if (target is Player)
            {
                return String.Format(FILEPATH_PLAYER);
            }
            else if (target is Npc)
            {
                return null;
            }
            else if (target is Command)
            {
                return String.Format(FILEPATH_COMMANDS, target.GetName());
            }
            else if (target is Director)
            {
                return String.Format(FILEPATH_DIRECTORS, ((Director)target).GetScriptPath());
            }
            else if (target is PrivateAreaContent)
            {
                return String.Format(FILEPATH_CONTENT, ((PrivateAreaContent)target).GetPrivateAreaName());
            }
            else if (target is Area)
            {
                return String.Format(FILEPATH_ZONE, ((Area)target).zoneName);
            }
            else if (target is Quest)
            {
                string initial = ((Quest)target).actorName.Substring(0, 3);
                string questName = ((Quest)target).actorName;
                return String.Format(FILEPATH_QUEST, initial, questName);
            }
            else
                return "";
        }

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

            if (File.Exists("./scripts/base/" + target.classPath + ".lua"))
                parent = LuaEngine.LoadScript("./scripts/base/" + target.classPath + ".lua", ref errorMsg);

            if (!errorMsg.Equals(""))
                SendError(player, errorMsg);

            Area area = target.zone;
            if (area is PrivateArea)
            {
                if (File.Exists(String.Format("./scripts/unique/{0}/privatearea/{1}_{2}/{3}/{4}.lua", area.zoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format("./scripts/unique/{0}/privatearea/{1}_{2}/{3}/{4}.lua", area.zoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId()), ref errorMsg);
            }
            else
            {
                if (File.Exists(String.Format("./scripts/unique/{0}/{1}/{2}.lua", area.zoneName, target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format("./scripts/unique/{0}/{1}/{2}.lua", area.zoneName, target.className, target.GetUniqueId()), ref errorMsg);
            }

            if (parent == null && child == null)
            {
                LuaEngine.SendError(player, String.Format("ERROR: Could not find script for actor {0}.", target.GetName()));
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

            if (File.Exists("./scripts/base/" + target.classPath + ".lua"))
                parent = LuaEngine.LoadScript("./scripts/base/" + target.classPath + ".lua", ref errorMsg);

            Area area = target.zone;
            if (area is PrivateArea)
            {
                if (File.Exists(String.Format("./scripts/unique/{0}/privatearea/{1}_{2}/{3}/{4}.lua", area.zoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format("./scripts/unique/{0}/privatearea/{1}_{2}/{3}/{4}.lua", area.zoneName, ((PrivateArea)area).GetPrivateAreaName(), ((PrivateArea)area).GetPrivateAreaType(), target.className, target.GetUniqueId()), ref errorMsg);
            }
            else
            {
                if (File.Exists(String.Format("./scripts/unique/{0}/{1}/{2}.lua", area.zoneName, target.className, target.GetUniqueId())))
                    child = LuaEngine.LoadScript(String.Format("./scripts/unique/{0}/{1}/{2}.lua", area.zoneName, target.className, target.GetUniqueId()), ref errorMsg);
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
            List<LuaParam> lparams = new List<LuaParam>();
            lparams.AddRange(eventStart.luaParams);
            lparams.Insert(0, new LuaParam(0, eventStart.eventType));
            lparams.Insert(1, new LuaParam(2, eventStart.eventName));
            LuaCoroutine coroutine = TakeEventWait(player);
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

        /// <summary>Parks a coroutine that yielded one of global.lua's waits (wait, waitForSignal,
        /// callClientFunction / kickEvent) until its wake-up.</summary>
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
                    GetInstance().AddWaitSignalCoroutine(coroutine, value[1] as string);
                    break;
                case "_WAIT_EVENT":
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
            
            // load from scripts/commands/gm/ directory
            var path = String.Format("./scripts/commands/gm/{0}.lua", cmd.ToLower());

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

                    // if this isnt a console command, make sure player exists
                    if (player != null)
                    {
                        if (permissions > 0 && !player.isGM)
                        {
                            Program.Log.Info("LuaEngine.RunGMCommand: {0}'s GM level is too low to use command {1}.", player.actorName, cmd);
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
        
        public static LuaScript LoadScript(string path, ref string errorMsg)
        {
            return ScriptEngine.Instance.Load(path);
        }

        /// <summary>Calls a battle/status hook. Null when the script lacks the function or the call
        /// errored; otherwise its first result as an int (0 when it returned no number).</summary>
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
            player.QueuePacket(EndEventPacket.BuildPacket(player.actorId, player.currentEventOwner, player.currentEventName, 0));
        }

    }
}
