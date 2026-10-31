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
using Meteor.Map.Actors;

namespace Meteor.Map
{
    // Leve acquisition tables (seed_leve_01_acquisition.sql). Every reader tolerates a missing table,
    // so a server without the seed still starts with no offers and allowances kept in memory.
    partial class Database
    {
        private static MySqlConnection OpenLeveConnection()
        {
            MySqlConnection conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD));
            conn.Open();
            return conn;
        }

        // Pack id -> aetheryte class id (client sheet guildlevePack).
        public static Dictionary<uint, uint> GetGuildlevePacks()
        {
            Dictionary<uint, uint> packs = new Dictionary<uint, uint>();
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT id, aetheryte FROM gamedata_guildleve_packs", conn);
                    using (MySqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                            packs[reader.GetUInt32(0)] = reader.GetUInt32(1);
                    }
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("gamedata_guildleve_packs unavailable (apply Data/sql/seed/seed_leve_01_acquisition.sql): {0}", e.Message);
            }
            return packs;
        }

        // Guildleve rows the client never names; never offered.
        public static HashSet<uint> GetUnusedGuildleves()
        {
            HashSet<uint> ids = new HashSet<uint>();
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT id FROM gamedata_guildleve_unused", conn);
                    using (MySqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                            ids.Add(reader.GetUInt32(0));
                    }
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("gamedata_guildleve_unused unavailable (apply Data/sql/seed/seed_leve_01_acquisition.sql): {0}", e.Message);
            }
            return ids;
        }

        // Last grant time in unix seconds; false when the character has no row yet.
        public static bool LoadLeveState(Player player, out int allowances, out uint lastGrant)
        {
            allowances = 0;
            lastGrant = 0;
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT allowances, lastAllowanceGrant FROM characters_leve_state WHERE characterId = @charaId", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    using (MySqlDataReader reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            allowances = reader.GetUInt16(0);
                            lastGrant = reader.GetUInt32(1);
                            return true;
                        }
                    }
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("characters_leve_state unavailable: {0}", e.Message);
            }
            return false;
        }

        public static void SaveLeveState(Player player, int allowances, uint lastGrant)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand(@"
                        INSERT INTO characters_leve_state (characterId, allowances, lastAllowanceGrant)
                        VALUES (@charaId, @allowances, @lastGrant)
                        ON DUPLICATE KEY UPDATE allowances = @allowances, lastAllowanceGrant = @lastGrant", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    cmd.Parameters.AddWithValue("@allowances", allowances);
                    cmd.Parameters.AddWithValue("@lastGrant", lastGrant);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
            }
        }

        // Every leve id (regional, or local 120xxx) this character has completed.
        public static HashSet<uint> GetCompletedGuildleves(Player player)
        {
            HashSet<uint> ids = new HashSet<uint>();
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT DISTINCT questId FROM characters_quest_guildlevehistory WHERE characterId = @charaId", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    using (MySqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                            ids.Add(reader.GetUInt32(0));
                    }
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
            }
            return ids;
        }

        public static void AddGuildleveHistory(Player player, uint id)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveConnection())
                {
                    MySqlCommand cmd = new MySqlCommand(@"
                        INSERT INTO characters_quest_guildlevehistory (characterId, questId, timeCompleted)
                        VALUES (@charaId, @questId, NOW())", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    cmd.Parameters.AddWithValue("@questId", id);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error(e.ToString());
            }
        }
    }
}
