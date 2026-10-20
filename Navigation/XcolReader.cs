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
using System.Buffers.Binary;
using System.Collections.Generic;
using System.IO;
using System.Numerics;
using System.Text.Json;

namespace Meteor.Navigation
{
    /// <summary>One row of groups.json (FORMATS §1).</summary>
    public sealed class XcolGroup
    {
        public int Id;
        public string Name;
        public string Object;
        public string Suffix;
        public int Kind;
        public string Primitive;
        /// <summary>Switchable tree (door, quest wall, gate).</summary>
        public bool Dynamic;
        /// <summary>"on", "off" or "unknown"; null for static groups.</summary>
        public string Initial;
    }

    /// <summary>A static.xcol triangle soup with its group table, as written by the collision exporter.</summary>
    public sealed class XcolFile
    {
        public Vector3 BoundsMin, BoundsMax;
        /// <summary>x, y, z per vertex.</summary>
        public float[] Vertices;
        /// <summary>a, b, c per triangle.</summary>
        public int[] Indices;
        public ushort[] Group;
        public byte[] Material;
        public byte[] Kind;
        public List<XcolGroup> Groups = new List<XcolGroup>();

        public int VertexCount => Vertices.Length / 3;
        public int TriangleCount => Group.Length;
    }

    /// <summary>Reads the collision exporter's .xcol + groups.json (FORMATS §1). Local data, never committed.</summary>
    public static class XcolReader
    {
        public const uint MAGIC = 0x4C4F4358; // 'XCOL'
        public const int VERSION = 1;
        private const int HEADER_SIZE = 56;

        /// <summary>Reads &lt;dir&gt;/static.xcol and &lt;dir&gt;/groups.json (groups.json may be missing).</summary>
        public static XcolFile LoadZone(string dir)
        {
            var x = Read(Path.Combine(dir, "static.xcol"));
            string groups = Path.Combine(dir, "groups.json");
            if (File.Exists(groups))
                x.Groups = ReadGroups(File.ReadAllText(groups));
            return x;
        }

        /// <summary>
        /// Collision folder per zone name from &lt;root&gt;/zones.json, sameAs followed (FORMATS §1). Zones whose
        /// folder has no static.xcol are left out. Names are case-insensitive.
        /// </summary>
        public static Dictionary<string, string> ResolveZones(string root)
        {
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            string path = Path.Combine(root, "zones.json");
            if (!File.Exists(path))
                return result;
            var sameAs = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            using (var doc = JsonDocument.Parse(File.ReadAllText(path)))
            {
                if (!doc.RootElement.TryGetProperty("zones", out var zones) || zones.ValueKind != JsonValueKind.Object)
                    return result;
                foreach (var z in zones.EnumerateObject())
                    sameAs[z.Name] = Str(z.Value, "sameAs");
            }
            foreach (var zone in sameAs.Keys)
            {
                string name = zone;
                var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                while (name != null && sameAs.TryGetValue(name, out var next) && next != null && seen.Add(name))
                    name = next;
                string dir = Path.Combine(root, name);
                if (File.Exists(Path.Combine(dir, "static.xcol")))
                    result[zone] = dir;
            }
            return result;
        }

        /// <summary>The header's bounds only (min, max), without reading the triangles.</summary>
        public static (Vector3 min, Vector3 max) ReadBounds(string path)
        {
            var d = new byte[HEADER_SIZE];
            using (var f = File.OpenRead(path))
                if (f.Read(d, 0, HEADER_SIZE) != HEADER_SIZE || BinaryPrimitives.ReadUInt32LittleEndian(d) != MAGIC)
                    throw new InvalidDataException($"{path}: not an .xcol file");
            return (new Vector3(F(d, 32), F(d, 36), F(d, 40)), new Vector3(F(d, 44), F(d, 48), F(d, 52)));
        }

        public static XcolFile Read(string path) => Parse(File.ReadAllBytes(path), path);

        public static XcolFile Parse(byte[] d, string name = "xcol")
        {
            if (d.Length < HEADER_SIZE || BinaryPrimitives.ReadUInt32LittleEndian(d) != MAGIC)
                throw new InvalidDataException($"{name}: not an .xcol file");
            int version = BinaryPrimitives.ReadInt32LittleEndian(d.AsSpan(4));
            if (version != VERSION)
                throw new InvalidDataException($"{name}: .xcol version {version}, expected {VERSION}");
            int nv = BinaryPrimitives.ReadInt32LittleEndian(d.AsSpan(8));
            int nt = BinaryPrimitives.ReadInt32LittleEndian(d.AsSpan(12));
            if (nv < 0 || nt < 0 || HEADER_SIZE + 12L * nv + 16L * nt != d.Length)
                throw new InvalidDataException($"{name}: size mismatch ({nv} vertices, {nt} triangles, {d.Length} bytes)");

            var x = new XcolFile
            {
                BoundsMin = new Vector3(F(d, 32), F(d, 36), F(d, 40)),
                BoundsMax = new Vector3(F(d, 44), F(d, 48), F(d, 52)),
                Vertices = new float[nv * 3],
                Indices = new int[nt * 3],
                Group = new ushort[nt],
                Material = new byte[nt],
                Kind = new byte[nt],
            };
            int o = HEADER_SIZE;
            for (int i = 0; i < nv * 3; i++, o += 4)
                x.Vertices[i] = F(d, o);
            for (int t = 0; t < nt; t++, o += 16)
            {
                for (int k = 0; k < 3; k++)
                {
                    uint v = BinaryPrimitives.ReadUInt32LittleEndian(d.AsSpan(o + 4 * k));
                    if (v >= (uint)nv)
                        throw new InvalidDataException($"{name}: triangle {t} vertex {v} out of range");
                    x.Indices[t * 3 + k] = (int)v;
                }
                x.Group[t] = BinaryPrimitives.ReadUInt16LittleEndian(d.AsSpan(o + 12));
                x.Material[t] = d[o + 14];
                x.Kind[t] = d[o + 15];
            }
            return x;
        }

        public static List<XcolGroup> ReadGroups(string json)
        {
            var list = new List<XcolGroup>();
            using (var doc = JsonDocument.Parse(json))
            {
                if (!doc.RootElement.TryGetProperty("groups", out var groups) || groups.ValueKind != JsonValueKind.Array)
                    return list;
                int i = 0;
                foreach (var g in groups.EnumerateArray())
                {
                    var e = new XcolGroup
                    {
                        Id = g.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.Number ? id.GetInt32() : i,
                        Name = Str(g, "name"),
                        Object = Str(g, "object"),
                        Suffix = Str(g, "suffix"),
                        Kind = g.TryGetProperty("kind", out var k) && k.ValueKind == JsonValueKind.Number ? k.GetInt32() : 0,
                        Primitive = Str(g, "primitive"),
                    };
                    if (g.TryGetProperty("dynamic", out var dyn) && dyn.ValueKind == JsonValueKind.Object)
                    {
                        e.Dynamic = true;
                        e.Initial = Str(dyn, "initial") ?? "unknown";
                    }
                    list.Add(e);
                    i++;
                }
            }
            list.Sort((a, b) => a.Id.CompareTo(b.Id));
            return list;
        }

        private static float F(byte[] d, int o) => BinaryPrimitives.ReadSingleLittleEndian(d.AsSpan(o));

        private static string Str(JsonElement e, string name) =>
            e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
    }
}
