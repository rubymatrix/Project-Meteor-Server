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
using System;
using System.Collections.Generic;
using System.Globalization;

namespace Meteor.Map.DataObjects
{
    // A consumable's effects from server_items_consumable: each buff is min(stat x %, cap) or a
    // flat value.
    class ConsumableData
    {
        public const string TYPE_FOOD = "food";
        public const string TYPE_RESTORE = "restore";
        public const string TYPE_MEDICINE = "medicine";
        public const string TYPE_CURE = "cure";
        // Scripted in Battle/Items.lua (enfeebling potions, tonics, unguents, Lunar Curtain).
        public const string TYPE_SCRIPT = "script";

        public struct Effect
        {
            public uint modifier;
            public double pct;
            public int cap;
            public int flat;
            public bool isFlat;

            public int Compute(double value)
            {
                if (isFlat)
                    return flat;
                int amount = (int)Math.Floor(Math.Max(0, value) * pct / 100.0);
                return cap > 0 ? Math.Min(amount, cap) : amount;
            }
        }

        public readonly uint itemId;
        public readonly string name;
        public readonly string type;
        public readonly uint statusId;
        public readonly List<Effect> effects = new List<Effect>();
        public readonly List<uint> removeStatus = new List<uint>();

        private static readonly object loadLock = new object();
        private static Dictionary<uint, ConsumableData> table;

        public ConsumableData(MySqlDataReader reader)
        {
            itemId = reader.GetUInt32("itemId");
            name = reader.GetString("name");
            type = reader.GetString("type");
            statusId = reader.GetUInt32("statusId");

            foreach (string part in reader.GetString("effects").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string[] f = part.Split(':');
                Effect e = new Effect();
                e.modifier = uint.Parse(f[0]);
                if (f.Length == 2 && f[1].StartsWith("="))
                {
                    e.isFlat = true;
                    e.flat = int.Parse(f[1].Substring(1), CultureInfo.InvariantCulture);
                }
                else
                {
                    e.pct = double.Parse(f[1], CultureInfo.InvariantCulture);
                    e.cap = f.Length > 2 ? int.Parse(f[2], CultureInfo.InvariantCulture) : 0;
                }
                effects.Add(e);
            }

            foreach (string id in reader.GetString("removeStatus").Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
                removeStatus.Add(uint.Parse(id.Trim()));
        }

        public bool IsSupported()
        {
            return type == TYPE_FOOD || type == TYPE_RESTORE || type == TYPE_MEDICINE || type == TYPE_CURE || type == TYPE_SCRIPT;
        }

        public static ConsumableData Get(uint itemId)
        {
            lock (loadLock)
            {
                if (table == null)
                    Load();
                ConsumableData data;
                return table.TryGetValue(itemId, out data) ? data : null;
            }
        }

        public static int Load()
        {
            var loaded = new Dictionary<uint, ConsumableData>();
            using (MySqlConnection conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD)))
            {
                try
                {
                    conn.Open();
                    using (MySqlDataReader reader = new MySqlCommand("SELECT itemId, name, type, statusId, effects, removeStatus FROM server_items_consumable", conn).ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            try
                            {
                                var data = new ConsumableData(reader);
                                loaded[data.itemId] = data;
                            }
                            catch (FormatException e)
                            {
                                Program.Log.Error("server_items_consumable row {0}: {1}", reader.GetUInt32("itemId"), e.Message);
                            }
                        }
                    }
                }
                catch (MySqlException e)
                {
                    Program.Log.Error(e.ToString());
                }
            }
            lock (loadLock)
                table = loaded;
            Program.Log.Info("Loaded {0} consumables.", loaded.Count);
            return loaded.Count;
        }
    }
}
