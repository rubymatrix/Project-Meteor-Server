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
using System.Security.Cryptography;
using System.Text;

using MySql.Data.MySqlClient;

namespace Meteor.Web
{
    // Accounts and game sessions, in the formats the Lobby Server and existing accounts use:
    // users.passhash = sha224_hex(password + salt), sessions.id = 56 hex chars (28 bytes), one
    // session per user.
    static class AccountService
    {
        // Returns the user id, or 0 if the name or password is wrong.
        public static uint VerifyUser(string name, string password)
        {
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
            {
                conn.Open();
                MySqlCommand cmd = new MySqlCommand("SELECT id, passhash, salt FROM users WHERE name = @name", conn);
                cmd.Parameters.AddWithValue("@name", name);
                using (MySqlDataReader reader = cmd.ExecuteReader())
                {
                    if (!reader.Read())
                        return 0;

                    uint id = reader.GetUInt32("id");
                    string stored = reader.GetString("passhash");
                    string hashed = Sha224Hex(password + reader.GetString("salt"));
                    bool ok = CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(hashed), Encoding.ASCII.GetBytes(stored.ToLowerInvariant()));
                    return ok ? id : 0;
                }
            }
        }

        public enum CreateResult { Created, NameTaken }

        public static CreateResult CreateUser(string name, string password, string email)
        {
            string salt = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(28));
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
            {
                conn.Open();
                MySqlCommand cmd = new MySqlCommand("INSERT INTO users (name, passhash, salt, email) VALUES (@name, @passhash, @salt, @email)", conn);
                cmd.Parameters.AddWithValue("@name", name);
                cmd.Parameters.AddWithValue("@passhash", Sha224Hex(password + salt));
                cmd.Parameters.AddWithValue("@salt", salt);
                cmd.Parameters.AddWithValue("@email", email);
                try
                {
                    cmd.ExecuteNonQuery();
                }
                catch (MySqlException e) when (e.Number == 1062)
                {
                    // users.name is unique.
                    return CreateResult.NameTaken;
                }
                return CreateResult.Created;
            }
        }

        // Reuses the user's live session (pushing its expiry out) or replaces it with a new one.
        public static string RefreshOrCreateSession(uint userId)
        {
            int hours = ConfigConstants.SESSION_HOURS;
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
            {
                conn.Open();

                MySqlCommand select = new MySqlCommand("SELECT id FROM sessions WHERE userid = @userId AND expiration > NOW()", conn);
                select.Parameters.AddWithValue("@userId", userId);
                object existing = select.ExecuteScalar();
                if (existing != null)
                {
                    MySqlCommand refresh = new MySqlCommand("UPDATE sessions SET expiration = NOW() + INTERVAL @hours HOUR WHERE id = @id", conn);
                    refresh.Parameters.AddWithValue("@hours", hours);
                    refresh.Parameters.AddWithValue("@id", (string)existing);
                    refresh.ExecuteNonQuery();
                    return (string)existing;
                }

                string sessionId = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(28));
                MySqlCommand delete = new MySqlCommand("DELETE FROM sessions WHERE userid = @userId", conn);
                delete.Parameters.AddWithValue("@userId", userId);
                delete.ExecuteNonQuery();

                MySqlCommand insert = new MySqlCommand("INSERT INTO sessions (id, userid, expiration) VALUES (@id, @userId, NOW() + INTERVAL @hours HOUR)", conn);
                insert.Parameters.AddWithValue("@id", sessionId);
                insert.Parameters.AddWithValue("@userId", userId);
                insert.Parameters.AddWithValue("@hours", hours);
                insert.ExecuteNonQuery();
                return sessionId;
            }
        }

        public static string Sha224Hex(string text)
        {
            return Convert.ToHexStringLower(Sha224.Hash(Encoding.UTF8.GetBytes(text)));
        }
    }
}
