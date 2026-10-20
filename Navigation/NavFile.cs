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
using System.Globalization;
using System.IO;
using System.Numerics;
using System.Text;
using System.Text.Json;
using DotRecast.Core.Numerics;
using DotRecast.Detour;

namespace Meteor.Navigation
{
    public sealed class NavTileBlob
    {
        public long TileRef;
        public byte[] Data;
    }

    public sealed class NavAreaDef
    {
        public int Id;
        public string Name;
        public int Flags;
        public float Cost = 1.0f;
    }

    public sealed class NavGateDef
    {
        public int Index;
        public string Id;
        public string Kind;
        /// <summary>"open", "closed" or "unknown" (treated as open: the mesh is built open).</summary>
        public string Default;
        /// <summary>Driver fields as strings (arrays joined with ','), e.g. mapobj, timeline.</summary>
        public Dictionary<string, string> Driver = new Dictionary<string, string>(StringComparer.Ordinal);
        public string DriverJson;
        public long[] Polys = Array.Empty<long>();
        public int[] Links = Array.Empty<int>();
        /// <summary>"block" (shown = in the way), "surface" (shown = the walkway exists) or "both".</summary>
        public string Role = "block";
        /// <summary>Timeline name -> passable after it plays, as navgen worked it out for this gate.</summary>
        public Dictionary<string, bool> Passable = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        /// <summary>The collision group (groups.json name) an edit-layer gate binds; null when unset.</summary>
        public string Group;

        public bool DefaultOpen => !string.Equals(Default, "closed", StringComparison.OrdinalIgnoreCase);
    }

    public sealed class NavLinkDef
    {
        public int Index;
        public string Id;
        public string Kind;
        public int Gate = -1;
        public Vector3 A, B;
        public bool Bidir;
    }

    public sealed class NavSeedDef
    {
        public string Id;
        public Vector3 Pos;
        public string Label;
    }

    public struct NavGraphNode
    {
        public int CellX, CellZ;
        public Vector3 Center;
        public long CenterPoly;
        public int Gate;
        public int Island;
        public int Flags;
    }

    public struct NavGraphEdge
    {
        public int From, To;
        public float Cost;
        public int Gate;
        public int Flags;
    }

    public sealed class NavGraphData
    {
        public float CellSize;
        public NavGraphNode[] Nodes;
        public NavGraphEdge[] Edges;
        /// <summary>Node per poly in TILE order; -1 for pruned polys.</summary>
        public int[] PolyNode;
    }

    /// <summary>Effective build settings from META (metres, after voxel rounding).</summary>
    public sealed class NavMeta
    {
        public string Zone;
        public string NavgenVersion;
        public string Built;
        public float CellSize, CellHeight;
        public float WalkableHeight = 2.0f, WalkableClimb = 0.75f, WalkableRadius;
    }

    /// <summary>
    /// Reader for navgen .nav files (FORMATS §4). Little-endian; unknown sections are skipped.
    /// </summary>
    public sealed class NavFile
    {
        public const int VERSION = 1;
        public const int MAX_VERTS_PER_POLY = 6;

        public static readonly uint MAGIC = FourCC("XNAV");
        public static readonly uint META = FourCC("META"), PARM = FourCC("PARM"), TILE = FourCC("TILE"),
            AREA = FourCC("AREA"), GATE = FourCC("GATE"), LINK = FourCC("LINK"), SEED = FourCC("SEED"),
            ISLD = FourCC("ISLD"), GRPH = FourCC("GRPH"), VALD = FourCC("VALD");

        public int Version;
        public readonly List<string> Sections = new List<string>();
        public string MetaJson;
        public NavMeta Meta = new NavMeta();
        public bool HasParams;
        public DtNavMeshParams Params;
        public readonly List<NavTileBlob> Tiles = new List<NavTileBlob>();
        public readonly List<NavAreaDef> Areas = new List<NavAreaDef>();
        public readonly List<NavGateDef> Gates = new List<NavGateDef>();
        public readonly List<NavLinkDef> Links = new List<NavLinkDef>();
        public readonly List<NavSeedDef> Seeds = new List<NavSeedDef>();
        public uint[] Islands;
        public NavGraphData Graph;
        public string ValidationJson;

        /// <summary>The four characters in file order, read as a little-endian u32.</summary>
        public static uint FourCC(string s) => (uint)(s[0] | s[1] << 8 | s[2] << 16 | s[3] << 24);

        public static string FourCCName(uint v) =>
            new string(new[] { (char)(v & 0xFF), (char)((v >> 8) & 0xFF), (char)((v >> 16) & 0xFF), (char)(v >> 24) });

        public static NavFile Read(string path)
        {
            using (var stream = File.OpenRead(path))
            {
                try { return Read(stream); }
                catch (InvalidDataException e) { throw new InvalidDataException($"{path}: {e.Message}", e); }
            }
        }

        public static NavFile Read(Stream stream)
        {
            var file = new NavFile();
            var r = new BinaryReader(stream, Encoding.UTF8, true);
            long origin = stream.Position;

            if (r.ReadUInt32() != MAGIC)
                throw new InvalidDataException("not a .nav file (bad magic)");
            file.Version = r.ReadInt32();
            if (file.Version != VERSION)
                throw new InvalidDataException($"unsupported .nav version {file.Version}");
            int sectionCount = r.ReadInt32();
            r.ReadUInt32();

            var table = new List<(uint fourcc, long offset, long size)>(sectionCount);
            for (int i = 0; i < sectionCount; i++)
            {
                uint fourcc = r.ReadUInt32();
                r.ReadUInt32();
                long offset = (long)r.ReadUInt64();
                long size = (long)r.ReadUInt64();
                table.Add((fourcc, offset, size));
            }

            foreach (var (fourcc, offset, size) in table)
            {
                file.Sections.Add(FourCCName(fourcc));
                if (size > int.MaxValue)
                    throw new InvalidDataException($"section {FourCCName(fourcc)} too large");
                stream.Position = origin + offset;
                byte[] bytes = r.ReadBytes((int)size);
                if (bytes.Length != size)
                    throw new InvalidDataException($"section {FourCCName(fourcc)} truncated");

                if (fourcc == META) file.ReadMeta(bytes);
                else if (fourcc == PARM) file.ReadParams(bytes);
                else if (fourcc == TILE) file.ReadTiles(bytes);
                else if (fourcc == AREA) file.ReadAreas(bytes);
                else if (fourcc == GATE) file.ReadGates(bytes);
                else if (fourcc == LINK) file.ReadLinks(bytes);
                else if (fourcc == SEED) file.ReadSeeds(bytes);
                else if (fourcc == ISLD) file.ReadIslands(bytes);
                else if (fourcc == GRPH) file.ReadGraph(bytes);
                else if (fourcc == VALD) file.ValidationJson = Encoding.UTF8.GetString(bytes);
            }

            if (!file.HasParams)
                throw new InvalidDataException("missing PARM section");
            return file;
        }

        #region Sections

        private void ReadMeta(byte[] bytes)
        {
            MetaJson = Encoding.UTF8.GetString(bytes);
            using (var doc = JsonDocument.Parse(bytes))
            {
                var root = doc.RootElement;
                Meta.Zone = Str(root, "zone");
                Meta.NavgenVersion = Str(root, "navgenVersion");
                Meta.Built = Str(root, "built");
                if (root.TryGetProperty("effective", out var eff) && eff.ValueKind == JsonValueKind.Object)
                {
                    Meta.CellSize = Num(eff, "cs", 0);
                    Meta.CellHeight = Num(eff, "ch", 0);
                    Meta.WalkableHeight = Num(eff, "walkableHeight", Meta.WalkableHeight);
                    Meta.WalkableClimb = Num(eff, "walkableClimb", Meta.WalkableClimb);
                    Meta.WalkableRadius = Num(eff, "walkableRadius", Meta.WalkableRadius);
                }
            }
        }

        private void ReadParams(byte[] bytes)
        {
            var r = new BinaryReader(new MemoryStream(bytes));
            Params = new DtNavMeshParams
            {
                orig = new RcVec3f(r.ReadSingle(), r.ReadSingle(), r.ReadSingle()),
                tileWidth = r.ReadSingle(),
                tileHeight = r.ReadSingle(),
                maxTiles = r.ReadInt32(),
                maxPolys = r.ReadInt32(),
            };
            HasParams = true;
        }

        private void ReadTiles(byte[] bytes)
        {
            var r = new BinaryReader(new MemoryStream(bytes));
            uint count = r.ReadUInt32();
            for (uint i = 0; i < count; i++)
            {
                long tileRef = (long)r.ReadUInt64();
                int dataSize = r.ReadInt32();
                r.ReadUInt32();
                if (dataSize < 0 || r.BaseStream.Position + dataSize > bytes.Length)
                    throw new InvalidDataException($"TILE entry {i} truncated");
                byte[] data = r.ReadBytes(dataSize);
                r.BaseStream.Position += (8 - dataSize % 8) % 8;
                Tiles.Add(new NavTileBlob { TileRef = tileRef, Data = data });
            }
        }

        private void ReadAreas(byte[] bytes)
        {
            using (var doc = JsonDocument.Parse(bytes))
                foreach (var e in doc.RootElement.EnumerateArray())
                    Areas.Add(new NavAreaDef
                    {
                        Id = (int)Num(e, "id", 0),
                        Name = Str(e, "name"),
                        Flags = (int)Num(e, "flags", 0),
                        Cost = Num(e, "cost", 1.0f),
                    });
        }

        private void ReadGates(byte[] bytes)
        {
            using (var doc = JsonDocument.Parse(bytes))
            {
                int i = 0;
                foreach (var e in doc.RootElement.EnumerateArray())
                {
                    var gate = new NavGateDef
                    {
                        Index = (int)Num(e, "index", i),
                        Id = Str(e, "id"),
                        Kind = Str(e, "kind"),
                        Default = Str(e, "default") ?? "unknown",
                        Role = Str(e, "role") ?? "block",
                        Group = Str(e, "group"),
                    };
                    if (e.TryGetProperty("passable", out var passable) && passable.ValueKind == JsonValueKind.Object)
                    {
                        foreach (var p in passable.EnumerateObject())
                            if (p.Value.ValueKind == JsonValueKind.True || p.Value.ValueKind == JsonValueKind.False)
                                gate.Passable[p.Name] = p.Value.GetBoolean();
                    }
                    if (e.TryGetProperty("driver", out var driver) && driver.ValueKind == JsonValueKind.Object)
                    {
                        gate.DriverJson = driver.GetRawText();
                        foreach (var p in driver.EnumerateObject())
                            gate.Driver[p.Name] = Flatten(p.Value);
                    }
                    if (e.TryGetProperty("polys", out var polys) && polys.ValueKind == JsonValueKind.Array)
                    {
                        var list = new List<long>();
                        foreach (var p in polys.EnumerateArray())
                            list.Add(ParseRef(p));
                        gate.Polys = list.ToArray();
                    }
                    if (e.TryGetProperty("links", out var links) && links.ValueKind == JsonValueKind.Array)
                    {
                        var list = new List<int>();
                        foreach (var l in links.EnumerateArray())
                            list.Add(l.GetInt32());
                        gate.Links = list.ToArray();
                    }
                    Gates.Add(gate);
                    i++;
                }
            }
            Gates.Sort((a, b) => a.Index.CompareTo(b.Index));
        }

        private void ReadLinks(byte[] bytes)
        {
            using (var doc = JsonDocument.Parse(bytes))
            {
                int i = 0;
                foreach (var e in doc.RootElement.EnumerateArray())
                {
                    Links.Add(new NavLinkDef
                    {
                        Index = (int)Num(e, "index", i),
                        Id = Str(e, "id"),
                        Kind = Str(e, "kind"),
                        Gate = e.TryGetProperty("gate", out var g) && g.ValueKind == JsonValueKind.Number ? g.GetInt32() : -1,
                        A = Vec(e, "a"),
                        B = Vec(e, "b"),
                        Bidir = e.TryGetProperty("bidir", out var b) && b.ValueKind == JsonValueKind.True,
                    });
                    i++;
                }
            }
            Links.Sort((a, b) => a.Index.CompareTo(b.Index));
        }

        private void ReadSeeds(byte[] bytes)
        {
            using (var doc = JsonDocument.Parse(bytes))
                foreach (var e in doc.RootElement.EnumerateArray())
                    Seeds.Add(new NavSeedDef { Id = Str(e, "id"), Pos = Vec(e, "pos"), Label = Str(e, "label") });
        }

        private void ReadIslands(byte[] bytes)
        {
            var r = new BinaryReader(new MemoryStream(bytes));
            uint count = r.ReadUInt32();
            if (4 + (long)count * 4 > bytes.Length)
                throw new InvalidDataException("ISLD truncated");
            Islands = new uint[count];
            for (int i = 0; i < count; i++)
                Islands[i] = r.ReadUInt32();
        }

        private void ReadGraph(byte[] bytes)
        {
            var r = new BinaryReader(new MemoryStream(bytes));
            var g = new NavGraphData { CellSize = r.ReadSingle() };
            uint nodeCount = r.ReadUInt32(), edgeCount = r.ReadUInt32(), polyCount = r.ReadUInt32();
            if (16 + nodeCount * 40L + edgeCount * 20L + polyCount * 4L > bytes.Length)
                throw new InvalidDataException("GRPH truncated");

            g.Nodes = new NavGraphNode[nodeCount];
            for (int i = 0; i < nodeCount; i++)
            {
                g.Nodes[i] = new NavGraphNode
                {
                    CellX = r.ReadInt32(),
                    CellZ = r.ReadInt32(),
                    Center = new Vector3(r.ReadSingle(), r.ReadSingle(), r.ReadSingle()),
                    CenterPoly = (long)r.ReadUInt64(),
                    Gate = r.ReadInt32(),
                    Island = (int)r.ReadUInt32(),
                    Flags = (int)r.ReadUInt32(),
                };
            }
            g.Edges = new NavGraphEdge[edgeCount];
            for (int i = 0; i < edgeCount; i++)
            {
                g.Edges[i] = new NavGraphEdge
                {
                    From = (int)r.ReadUInt32(),
                    To = (int)r.ReadUInt32(),
                    Cost = r.ReadSingle(),
                    Gate = r.ReadInt32(),
                    Flags = (int)r.ReadUInt32(),
                };
                if (g.Edges[i].From >= nodeCount || g.Edges[i].To >= nodeCount)
                    throw new InvalidDataException($"GRPH edge {i} points past the node table");
            }
            g.PolyNode = new int[polyCount];
            for (int i = 0; i < polyCount; i++)
            {
                uint n = r.ReadUInt32();
                g.PolyNode[i] = n == 0xFFFFFFFF || n >= nodeCount ? -1 : (int)n;
            }
            Graph = g;
        }

        #endregion

        #region JSON helpers

        private static string Str(JsonElement e, string name) =>
            e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

        private static float Num(JsonElement e, string name, float fallback) =>
            e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetSingle() : fallback;

        private static Vector3 Vec(JsonElement e, string name)
        {
            if (!e.TryGetProperty(name, out var v) || v.ValueKind != JsonValueKind.Array || v.GetArrayLength() < 3)
                return default;
            return new Vector3(v[0].GetSingle(), v[1].GetSingle(), v[2].GetSingle());
        }

        private static string Flatten(JsonElement v)
        {
            switch (v.ValueKind)
            {
                case JsonValueKind.String: return v.GetString();
                case JsonValueKind.Array:
                    var parts = new List<string>();
                    foreach (var x in v.EnumerateArray())
                        parts.Add(Flatten(x));
                    return string.Join(",", parts);
                default: return v.GetRawText();
            }
        }

        internal static long ParseRef(JsonElement p)
        {
            if (p.ValueKind == JsonValueKind.Number)
                return p.GetInt64();
            string s = p.GetString() ?? "0";
            if (s.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
                return (long)ulong.Parse(s.Substring(2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return long.Parse(s, CultureInfo.InvariantCulture);
        }

        #endregion
    }
}
