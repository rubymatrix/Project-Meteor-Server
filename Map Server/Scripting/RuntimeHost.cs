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

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.AI;
using Meteor.Map.AI.Behaviors;
using Meteor.Map.Content;
using Meteor.Map.lua;

namespace Meteor.Map.Scripting
{
    // What the Lua runtime calls into: files, time, factions, content objects, saved state.
    class RuntimeHost
    {
        public string Root => ConfigConstants.OPTIONS_SCRIPTPATH ?? "./scripts";

        public double NowMs => GameClock.NowMs;

        public object Stamp(string path)
        {
            var info = new FileInfo(path);
            return info.Exists ? (object)(double)(info.LastWriteTimeUtc.Ticks / TimeSpan.TicksPerMillisecond) : null;
        }

        public bool Exists(string path) => File.Exists(path);

        public void Log(string level, string message)
        {
            switch (level)
            {
                case "error": ScriptEngine.Log.Error(message); break;
                case "warn": ScriptEngine.Log.Warn(message); break;
                case "debug": ScriptEngine.Log.Debug(message); break;
                default: ScriptEngine.Log.Info(message); break;
            }
        }

        public Vector3 Vec(double x, double y, double z) => new Vector3((float)x, (float)y, (float)z);

        // Script module names (no extension) under a folder of the scripts root.
        public List<string> ListScripts(string dir)
        {
            var list = new List<string>();
            string full = Path.Combine(Root, dir);
            if (!Directory.Exists(full))
                return list;
            foreach (var f in Directory.GetFiles(full, "*.lua"))
                list.Add(dir.TrimEnd('/') + "/" + Path.GetFileNameWithoutExtension(f));
            list.Sort(StringComparer.Ordinal);
            return list;
        }

        public List<string> ListDirs(string dir)
        {
            var list = new List<string>();
            string full = Path.Combine(Root, dir);
            if (!Directory.Exists(full))
                return list;
            foreach (var d in Directory.GetDirectories(full))
                list.Add(dir.TrimEnd('/') + "/" + Path.GetFileName(d));
            list.Sort(StringComparer.Ordinal);
            return list;
        }

        public bool IsStockBehavior(string kind) => BehaviorRegistry.IsStock(kind);

        #region Factions

        public int DefineFaction(string name) => Factions.Define(name);

        public void Relate(string a, string b, string relation) => Factions.Relate(a, b, relation);

        public string FactionName(int id) => Factions.Name(id);

        public string RelationBetween(Character a, Character b) => Factions.Between(a, b).ToString().ToLowerInvariant();

        #endregion

        #region Content

        public Encounter NewEncounter(string name, string variant, Area area, string scope, double seed)
        {
            var s = Enum.TryParse<EncounterScope>(scope ?? "Encounter", true, out var sc) ? sc : EncounterScope.Encounter;
            var e = new Encounter(name, variant, area, s, seed > 0 ? (int?)seed : null);
            ContentManager.Add(e);
            return e;
        }

        public void Signal(Encounter enc, Character actor, string name, object data)
        {
            EventBus.Raise(new ActorEvent(ActorEventType.Signal, actor) { Encounter = enc, Name = name, Data = data });
        }

        public Encounter FindEncounter(int id) => ContentManager.Get(id);

        public Encounter EncounterFor(Player p) => ContentManager.ForPlayer(p);

        public List<Player> PlayersNear(Area area, double x, double y, double z, double radius)
        {
            var list = new List<Player>();
            if (area == null)
                return list;
            var centre = new Vector3((float)x, (float)y, (float)z);
            foreach (var p in area.GetPlayers())
                if (p.playerSession != null && Utils.Distance(p.GetPosAsVector3(), centre) <= radius)
                    list.Add(p);
            return list;
        }

        public Character ActorById(Area area, double id) => area?.FindActorInArea<Character>((uint)id);

        #endregion

        #region Saved state and lockouts

        public string LoadState(string key) => Database.LoadContentState(key);

        public void SaveState(string key, string json) => Database.SaveContentState(key, json);

        public void SetLockout(Player p, string name, double seconds)
        {
            if (p != null)
                Database.SetContentLockout(p.Id, name, (uint)(Utils.UnixTimeStampUTC() + Math.Max(0, seconds)));
        }

        public double LockoutRemaining(Player p, string name)
        {
            if (p == null)
                return 0;
            uint until = Database.GetContentLockout(p.Id, name);
            long left = (long)until - Utils.UnixTimeStampUTC();
            return Math.Max(0, left);
        }

        #endregion
    }
}
