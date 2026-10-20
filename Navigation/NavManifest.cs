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

namespace Meteor.Navigation
{
    /// <summary>
    /// navmeshes/manifest.json v2 (FORMATS §5): zone → .nav file, with sameAs zones resolved to the
    /// zone whose file they reuse. Zone names are case-insensitive.
    /// </summary>
    public sealed class NavManifest
    {
        public sealed class Entry
        {
            public string Zone;
            public string File;
            public string SameAs;
            public bool? Valid;
        }

        public int Version;
        public string Directory;
        public readonly Dictionary<string, Entry> Zones = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);

        public static NavManifest Load(string path)
        {
            var m = Parse(File.ReadAllText(path));
            m.Directory = Path.GetDirectoryName(Path.GetFullPath(path));
            return m;
        }

        public static NavManifest Parse(string json)
        {
            var m = new NavManifest();
            using (var doc = JsonDocument.Parse(json))
            {
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object)
                    throw new InvalidDataException("navmesh manifest version 1 (a list of .bin meshes), expected 2");
                m.Version = root.TryGetProperty("version", out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt32() : 0;
                if (m.Version != 2)
                    throw new InvalidDataException($"navmesh manifest version {m.Version}, expected 2");
                if (root.TryGetProperty("zones", out var zones) && zones.ValueKind == JsonValueKind.Object)
                {
                    foreach (var z in zones.EnumerateObject())
                    {
                        var e = new Entry { Zone = z.Name };
                        if (z.Value.TryGetProperty("file", out var f) && f.ValueKind == JsonValueKind.String)
                            e.File = f.GetString();
                        if (z.Value.TryGetProperty("sameAs", out var s) && s.ValueKind == JsonValueKind.String)
                            e.SameAs = s.GetString();
                        if (z.Value.TryGetProperty("valid", out var ok) && (ok.ValueKind == JsonValueKind.True || ok.ValueKind == JsonValueKind.False))
                            e.Valid = ok.GetBoolean();
                        m.Zones[z.Name] = e;
                    }
                }
            }
            return m;
        }

        /// <summary>The manifest's version without loading it: 1 for the old list of .bin meshes.</summary>
        public static int PeekVersion(string path)
        {
            using (var doc = JsonDocument.Parse(File.ReadAllText(path)))
            {
                var root = doc.RootElement;
                if (root.ValueKind == JsonValueKind.Array)
                    return 1;
                return root.ValueKind == JsonValueKind.Object && root.TryGetProperty("version", out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt32() : 0;
            }
        }

        /// <summary>The entry that owns zone's file after following sameAs (null if unlisted, cyclic or fileless).</summary>
        public Entry Resolve(string zone)
        {
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            while (zone != null && Zones.TryGetValue(zone, out var e))
            {
                if (!seen.Add(zone))
                    return null;
                if (e.File != null)
                    return e;
                zone = e.SameAs;
            }
            return null;
        }

        /// <summary>Full path of zone's .nav, or null.</summary>
        public string ResolveFile(string zone)
        {
            var e = Resolve(zone);
            if (e == null)
                return null;
            return Directory == null ? e.File : Path.Combine(Directory, e.File);
        }
    }
}
