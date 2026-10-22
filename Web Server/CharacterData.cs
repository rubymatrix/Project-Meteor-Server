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

using MySql.Data.MySqlClient;

namespace Meteor.Web
{
    // Read-only character data for the control panel. Every query is scoped to the owning user.
    static class CharacterData
    {
        public class CharacterSummary
        {
            public uint Id;
            public string Name;
        }

        public class CharacterSheet
        {
            public Dictionary<string, object> Profile;
            public Dictionary<string, object> Appearance;
            public Dictionary<string, object> ClassLevels;
            public Dictionary<string, object> Chocobo;
        }

        public static List<CharacterSummary> GetCharacters(uint userId)
        {
            List<CharacterSummary> characters = new List<CharacterSummary>();
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
            {
                conn.Open();
                MySqlCommand cmd = new MySqlCommand("SELECT id, name FROM characters WHERE userId = @userId ORDER BY id", conn);
                cmd.Parameters.AddWithValue("@userId", userId);
                using (MySqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                        characters.Add(new CharacterSummary { Id = reader.GetUInt32("id"), Name = reader.GetString("name") });
                }
            }
            return characters;
        }

        // Returns null if the character doesn't exist or isn't the user's.
        public static CharacterSheet GetSheet(uint userId, uint characterId)
        {
            using (MySqlConnection conn = new MySqlConnection(ConfigConstants.ConnectionString()))
            {
                conn.Open();
                Dictionary<string, object> profile = ReadRow(conn, "SELECT * FROM characters WHERE userId = @userId AND id = @characterId", userId, characterId);
                if (profile == null)
                    return null;

                return new CharacterSheet
                {
                    Profile = profile,
                    Appearance = ReadRow(conn, "SELECT a.* FROM characters_appearance a INNER JOIN characters c ON a.characterId = c.id WHERE c.userId = @userId AND c.id = @characterId", userId, characterId),
                    ClassLevels = ReadRow(conn, "SELECT l.* FROM characters_class_levels l INNER JOIN characters c ON l.characterId = c.id WHERE c.userId = @userId AND c.id = @characterId", userId, characterId),
                    Chocobo = ReadRow(conn, "SELECT h.* FROM characters_chocobo h INNER JOIN characters c ON h.characterId = c.id WHERE c.userId = @userId AND c.id = @characterId", userId, characterId),
                };
            }
        }

        static Dictionary<string, object> ReadRow(MySqlConnection conn, string sql, uint userId, uint characterId)
        {
            MySqlCommand cmd = new MySqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("@userId", userId);
            cmd.Parameters.AddWithValue("@characterId", characterId);
            using (MySqlDataReader reader = cmd.ExecuteReader())
            {
                if (!reader.Read())
                    return null;

                Dictionary<string, object> row = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                for (int i = 0; i < reader.FieldCount; i++)
                    row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                return row;
            }
        }
    }
}
