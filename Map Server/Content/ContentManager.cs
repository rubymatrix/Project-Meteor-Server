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
using System.Linq;
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.AI;
using Meteor.Map.Scripting;
using Meteor.Map.lua;
using Meteor.Map.actors.area;
using XLua;

namespace Meteor.Map.Content
{
    // Every running encounter, campaign and zone script, and the per-tick order they run in.
    static class ContentManager
    {
        private static readonly List<Encounter> encounters = new List<Encounter>();
        private static readonly Dictionary<string, int> zoneScripts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        private static readonly Dictionary<string, int> campaigns = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        public static IReadOnlyList<Encounter> Encounters => encounters;

        public static void Add(Encounter e)
        {
            if (!encounters.Contains(e))
                encounters.Add(e);
        }

        public static void Remove(Encounter e)
        {
            encounters.Remove(e);
        }

        public static Encounter Get(int id) => encounters.FirstOrDefault(e => e.Id == id);

        // Before the zones update.
        public static void BeginTick()
        {
            GameClock.Advance();
            EventBus.Drain();
        }

        // After the zones update: Lua tasks, then the events they raised.
        public static void EndTick()
        {
            if (ScriptRuntime.Loaded)
                ScriptRuntime.Instance.Tick();
            EventBus.Drain();
        }

        public static void TickArea(Area area)
        {
            foreach (var e in encounters.Where(x => x.Area == area).ToList())
            {
                try { e.Tick(); }
                catch (Exception ex) { Program.Log.Error("Content {0} #{1} tick failed: {2}", e.Name, e.Id, ex); }
            }
        }

        // Starts content by name: encounters/, content/instances, content/events.
        public static Encounter Start(string name, string variant, Area area, Player starter = null, LuaTable opts = null)
        {
            var r = ScriptRuntime.Instance.Call("rt_content_launch", name, variant ?? "", area, starter, opts);
            return r != null && r.Length > 0 ? r[0] as Encounter : null;
        }

        public static Encounter ForPlayer(Player p) => encounters.LastOrDefault(e => !e.IsOver && e.IsParticipant(p));

        public static Hazard HazardAt(Area area, Vector3 p, Character who)
        {
            if (area == null)
                return null;
            foreach (var e in encounters)
                if (e.Area == area)
                {
                    var h = e.HazardAt(p, who);
                    if (h != null)
                        return h;
                }
            return null;
        }

        #region Zone scripts and campaigns

        public static void LoadZoneScripts(IEnumerable<Area> zones)
        {
            foreach (var z in zones)
            {
                int id = ScriptRuntime.Instance.CallInt("rt_zone_load", z);
                if (id != 0)
                    zoneScripts[z.ZoneName] = id;
            }
        }

        public static void DeliverToZone(ActorEvent e)
        {
            var area = e.Actor?.CurrentArea ?? e.Encounter?.Area;
            if (area == null || e.Handled)
                return;
            string zone = area is PrivateArea pa ? pa.GetParentZone().ZoneName : area.ZoneName;
            if (zoneScripts.TryGetValue(zone, out int id))
                ScriptRuntime.Instance.Call("rt_content_event", id, e);
        }

        public static void StartCampaigns()
        {
            var r = ScriptRuntime.Instance.Call("rt_campaigns_start");
            if (r != null && r.Length > 0 && r[0] is LuaTableValue t)
                foreach (var kv in t.Pairs)
                    if (kv.Key is string name && kv.Value is double id)
                        campaigns[name] = (int)id;
        }

        public static IEnumerable<string> CampaignNames => campaigns.Keys;

        #endregion

        public static void Reset()
        {
            foreach (var e in encounters.ToList())
                e.Close();
            encounters.Clear();
            zoneScripts.Clear();
            campaigns.Clear();
        }

        public static string Describe()
        {
            var sb = new System.Text.StringBuilder();
            foreach (var e in encounters)
                sb.AppendFormat("#{0} {1} {2} [{3}] phase={4} area={5} seed={6} {7:0}s\n", e.Id, e.Name, e.Variant, e.State, e.Phase, e.Area?.ZoneName, e.Rng.Seed, e.Elapsed());
            foreach (var c in campaigns.Keys)
                sb.AppendFormat("campaign {0}\n", c);
            return sb.Length == 0 ? "no content running" : sb.ToString();
        }

        public static List<object> Snapshot()
        {
            var list = encounters.Select(e => e.Snapshot()).ToList();
            foreach (var c in campaigns)
            {
                var r = ScriptRuntime.Instance.Call("rt_content_describe", c.Value);
                list.Add(new { campaign = c.Key, script = c.Value, state = r?.FirstOrDefault() });
            }
            return list;
        }
    }
}
