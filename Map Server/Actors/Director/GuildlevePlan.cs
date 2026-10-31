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

using MySql.Data.MySqlClient;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Meteor.Map.actors.director
{
    // One battle leve's plan: what spawns, in which groups, and which kills count. Built by
    // Tools/seed/build_leve_seed.py and stored as JSON in server_guildleve_scripts. Pool ids are
    // server_battlenpc_pools ids (leve classes use poolId = actorClassId).
    class GuildlevePlan
    {
        public class Slot
        {
            public int slot;
            public uint pool;
            public int? size;   // monsters per group; null = default waves
            public int? concurrent;   // groups alive at once; null = default waves
        }

        public class Carrier
        {
            public int slot;
            public uint item;
            public List<List<uint>> groups = new List<List<uint>>();
        }

        public class Page
        {
            public int slot;
            public uint item;
            public List<uint> summon = new List<uint>();
        }

        public class Stop
        {
            public List<uint> wave = new List<uint>();
            public List<uint> add = new List<uint>();
        }

        public class Horde
        {
            public List<uint> pools = new List<uint>();
            public int min = 1;
        }

        public string kind;            // sweep, tutorial, chase, detect, gather, orb, hunt, round, survive
        public string source;          // elemen or default
        public List<Slot> slots = new List<Slot>();
        // detect / hunt
        public List<uint> decoy = new List<uint>();
        public List<uint> hit = new List<uint>();
        public int hits;
        // gather (and the orb drop variant)
        public List<Carrier> carriers = new List<Carrier>();
        public List<uint> carrier = new List<uint>();
        // orb / hunt
        public List<uint> miss = new List<uint>();
        public List<Page> pages = new List<Page>();
        public int points;
        // round
        public List<Stop> stops = new List<Stop>();
        // survive
        public int defense = 300;
        public List<Horde> horde = new List<Horde>();
        public List<uint> boss = new List<uint>();

        private static readonly Dictionary<uint, GuildlevePlan> cache = new Dictionary<uint, GuildlevePlan>();

        // Null when the leve has no row (not playable yet).
        public static GuildlevePlan Get(uint leveId)
        {
            lock (cache)
            {
                if (cache.TryGetValue(leveId, out var cached))
                    return cached;
            }
            GuildlevePlan plan = null;
            try
            {
                using (MySqlConnection conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD)))
                {
                    conn.Open();
                    MySqlCommand cmd = new MySqlCommand("SELECT script FROM server_guildleve_scripts WHERE leveId = @id", conn);
                    cmd.Parameters.AddWithValue("@id", leveId);
                    object result = cmd.ExecuteScalar();
                    if (result is string json)
                        plan = Parse(JObject.Parse(json));
                }
            }
            catch (Exception e)
            {
                Program.Log.Error("Guildleve {0}: could not load its plan (apply seed_leve_03_scripts.sql): {1}", leveId, e.Message);
                return null;   // not cached: a later start retries
            }
            lock (cache)
                cache[leveId] = plan;
            return plan;
        }

        // After re-seeding.
        public static void ClearCache()
        {
            lock (cache)
                cache.Clear();
        }

        private static List<uint> Pools(JToken t)
        {
            return t == null || t.Type != JTokenType.Array ? new List<uint>() : t.Select(x => (uint)x).ToList();
        }

        private static GuildlevePlan Parse(JObject o)
        {
            var p = new GuildlevePlan
            {
                kind = (string)o["kind"] ?? "sweep",
                source = (string)o["source"] ?? "default",
                decoy = Pools(o["decoy"]),
                hit = Pools(o["hit"]),
                hits = (int?)o["hits"] ?? 0,
                carrier = Pools(o["carrier"]),
                miss = Pools(o["miss"]),
                points = (int?)o["points"] ?? 0,
                defense = (int?)o["defense"] ?? 300,
                boss = Pools(o["boss"]),
            };
            foreach (var s in o["slots"] ?? new JArray())
                p.slots.Add(new Slot { slot = (int)s["slot"], pool = (uint?)s["pool"] ?? 0, size = (int?)s["size"], concurrent = (int?)s["concurrent"] });
            foreach (var c in o["carriers"] ?? new JArray())
            {
                var carrier = new Carrier { slot = (int)c["slot"], item = (uint)c["item"] };
                foreach (var g in c["groups"] ?? new JArray())
                    carrier.groups.Add(Pools(g));
                p.carriers.Add(carrier);
            }
            foreach (var pg in o["pages"] ?? new JArray())
                p.pages.Add(new Page { slot = (int)pg["slot"], item = (uint)pg["item"], summon = Pools(pg["summon"]) });
            foreach (var st in o["stops"] ?? new JArray())
                p.stops.Add(new Stop { wave = Pools(st["wave"]), add = Pools(st["add"]) });
            foreach (var h in o["horde"] ?? new JArray())
                p.horde.Add(new Horde { pools = Pools(h["pools"]), min = (int?)h["min"] ?? 1 });
            return p;
        }
    }
}
