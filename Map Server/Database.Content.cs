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
using MySql.Data.MySqlClient;

namespace Meteor.Map
{
    // Saved state for long-lived content (campaigns) and per-character content lockouts.
    partial class Database
    {
        private static MySqlConnection Open()
        {
            var conn = new MySqlConnection(String.Format("Server={0}; Port={1}; Database={2}; UID={3}; Password={4}", ConfigConstants.DATABASE_HOST, ConfigConstants.DATABASE_PORT, ConfigConstants.DATABASE_NAME, ConfigConstants.DATABASE_USERNAME, ConfigConstants.DATABASE_PASSWORD));
            conn.Open();
            return conn;
        }

        public static string LoadContentState(string key)
        {
            try
            {
                using (var conn = Open())
                {
                    var cmd = new MySqlCommand("SELECT data FROM server_content_state WHERE name = @name", conn);
                    cmd.Parameters.AddWithValue("@name", key);
                    return cmd.ExecuteScalar() as string;
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("Content state {0}: {1}", key, e.Message);
                return null;
            }
        }

        public static void SaveContentState(string key, string json)
        {
            try
            {
                using (var conn = Open())
                {
                    var cmd = new MySqlCommand("INSERT INTO server_content_state (name, data) VALUES (@name, @data) ON DUPLICATE KEY UPDATE data = @data", conn);
                    cmd.Parameters.AddWithValue("@name", key);
                    cmd.Parameters.AddWithValue("@data", json ?? "");
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("Content state {0}: {1}", key, e.Message);
            }
        }

        public static void SetContentLockout(uint characterId, string name, uint until)
        {
            try
            {
                using (var conn = Open())
                {
                    var cmd = new MySqlCommand("INSERT INTO characters_content_lockouts (characterId, name, until) VALUES (@id, @name, @until) ON DUPLICATE KEY UPDATE until = @until", conn);
                    cmd.Parameters.AddWithValue("@id", characterId);
                    cmd.Parameters.AddWithValue("@name", name);
                    cmd.Parameters.AddWithValue("@until", until);
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("Content lockout {0}: {1}", name, e.Message);
            }
        }

        public static uint GetContentLockout(uint characterId, string name)
        {
            try
            {
                using (var conn = Open())
                {
                    var cmd = new MySqlCommand("SELECT until FROM characters_content_lockouts WHERE characterId = @id AND name = @name", conn);
                    cmd.Parameters.AddWithValue("@id", characterId);
                    cmd.Parameters.AddWithValue("@name", name);
                    var r = cmd.ExecuteScalar();
                    return r == null || r is DBNull ? 0 : Convert.ToUInt32(r);
                }
            }
            catch (MySqlException e)
            {
                Program.Log.Error("Content lockout {0}: {1}", name, e.Message);
                return 0;
            }
        }
    }
}
