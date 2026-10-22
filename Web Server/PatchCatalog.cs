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
using System.Text.Json;

namespace Meteor.Web
{
    // The boot and game patch chains (web_patches.json) and the version the server targets in
    // each. An install can be behind the target (needs patches), at it, or ahead of it (a newer
    // client than this server supports; patches can't go backwards).
    static class PatchCatalog
    {
        public enum Standing { Unknown, Behind, Current, Ahead }

        static List<string> bootChain = new List<string>();
        static List<string> gameChain = new List<string>();
        static string bootTarget;
        static string gameTarget;

        public static bool Load(string path, string bootVersion, string gameVersion)
        {
            if (!File.Exists(path))
            {
                Program.Log.Error("{0} not found: only the target versions count as up to date", path);
                bootChain = new List<string> { bootVersion };
                gameChain = new List<string> { gameVersion };
            }
            else
            {
                using (JsonDocument doc = JsonDocument.Parse(File.ReadAllText(path)))
                {
                    bootChain = ReadChain(doc.RootElement, "boot");
                    gameChain = ReadChain(doc.RootElement, "game");
                }
            }

            bootTarget = bootVersion;
            gameTarget = gameVersion;

            bool ok = true;
            if (!bootChain.Contains(bootTarget))
            {
                Program.Log.Error("boot_version {0} isn't in the boot patch chain", bootTarget);
                ok = false;
            }
            if (!gameChain.Contains(gameTarget))
            {
                Program.Log.Error("game_version {0} isn't in the game patch chain", gameTarget);
                ok = false;
            }
            Program.Log.Info("Patch targets: boot {0}, game {1} ({2} of {3} game versions)", bootTarget, gameTarget,
                gameChain.IndexOf(gameTarget) + 1, gameChain.Count);
            return ok;
        }

        public static string Target(string repo)
        {
            return repo == "boot" ? bootTarget : gameTarget;
        }

        public static Standing Compare(string repo, string version)
        {
            List<string> chain = repo == "boot" ? bootChain : gameChain;
            int at = chain.IndexOf(version);
            int target = chain.IndexOf(Target(repo));
            if (at < 0 || target < 0)
                return Standing.Unknown;
            if (at < target)
                return Standing.Behind;
            return at == target ? Standing.Current : Standing.Ahead;
        }

        static List<string> ReadChain(JsonElement root, string name)
        {
            List<string> chain = new List<string>();
            if (root.TryGetProperty(name, out JsonElement list))
            {
                foreach (JsonElement version in list.EnumerateArray())
                    chain.Add(version.GetString());
            }
            return chain;
        }
    }
}
