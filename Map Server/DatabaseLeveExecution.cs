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
using Meteor.Map.actors.director;

namespace Meteor.Map
{
    // Battle leve tables (seed_leve_04_execution.sql). Readers tolerate a missing table.
    partial class Database
    {
        private static MySqlConnection OpenLeveExecConnection()
        {
            MySqlConnection conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD));
            conn.Open();
            return conn;
        }

        public static void AddPendingGuildleveReward(uint characterId, GuildleveDirector.LeveReward r)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand(@"
                        INSERT INTO characters_leve_pending_rewards (characterId, guildleveId, gil, item, quantity, completedAt)
                        VALUES (@charaId, @glId, @gil, @item, @qty, UNIX_TIMESTAMP())", conn);
                    cmd.Parameters.AddWithValue("@charaId", characterId);
                    cmd.Parameters.AddWithValue("@glId", r.glId);
                    cmd.Parameters.AddWithValue("@gil", r.gil);
                    cmd.Parameters.AddWithValue("@item", r.item2);
                    cmd.Parameters.AddWithValue("@qty", r.qty2);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("characters_leve_pending_rewards: {0}", e.Message);
            }
        }

        public static List<GuildleveDirector.LeveReward> GetPendingGuildleveRewards(Player player)
        {
            var list = new List<GuildleveDirector.LeveReward>();
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT guildleveId, gil, item, quantity FROM characters_leve_pending_rewards WHERE characterId = @charaId", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    using (MySqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                            list.Add(new GuildleveDirector.LeveReward { glId = reader.GetUInt32(0), gil = reader.GetUInt32(1), item2 = reader.GetUInt32(2), qty2 = reader.GetUInt32(3) });
                    }
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("characters_leve_pending_rewards unavailable: {0}", e.Message);
            }
            return list;
        }

        public static void ClearPendingGuildleveRewards(Player player)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("DELETE FROM characters_leve_pending_rewards WHERE characterId = @charaId", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("characters_leve_pending_rewards: {0}", e.Message);
            }
        }

        public static int GetFactionCredits(Player player, int faction)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT credits FROM characters_leve_faction WHERE characterId = @charaId AND faction = @faction", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    cmd.Parameters.AddWithValue("@faction", faction);
                    object v = cmd.ExecuteScalar();
                    return v == null ? 0 : Convert.ToInt32(v);
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("characters_leve_faction unavailable: {0}", e.Message);
                return 0;
            }
        }

        public static void SetFactionCredits(Player player, int faction, int credits)
        {
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand(@"
                        INSERT INTO characters_leve_faction (characterId, faction, credits) VALUES (@charaId, @faction, @credits)
                        ON DUPLICATE KEY UPDATE credits = @credits", conn);
                    cmd.Parameters.AddWithValue("@charaId", player.Id);
                    cmd.Parameters.AddWithValue("@faction", faction);
                    cmd.Parameters.AddWithValue("@credits", credits);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("characters_leve_faction: {0}", e.Message);
            }
        }

        private static readonly Dictionary<uint, uint> poolElements = new Dictionary<uint, uint>();

        // server_battlenpc_genus.element: 5 Fire .. 10 Water, 0 none.
        public static uint GetPoolElement(uint poolId)
        {
            lock (poolElements)
                if (poolElements.TryGetValue(poolId, out uint cached))
                    return cached;
            uint element = 0;
            try
            {
                using (MySqlConnection conn = OpenLeveExecConnection())
                {
                    MySqlCommand cmd = new MySqlCommand("SELECT g.element FROM server_battlenpc_pools p JOIN server_battlenpc_genus g ON g.genusId = p.genusId WHERE p.poolId = @poolId", conn);
                    cmd.Parameters.AddWithValue("@poolId", poolId);
                    object v = cmd.ExecuteScalar();
                    element = v == null ? 0 : Convert.ToUInt32(v);
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Warn("GetPoolElement({0}): {1}", poolId, e.Message);
            }
            lock (poolElements)
                poolElements[poolId] = element;
            return element;
        }
    }
}
