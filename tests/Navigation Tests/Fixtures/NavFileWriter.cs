using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.Json;
using DotRecast.Core;
using DotRecast.Detour;
using DotRecast.Detour.Io;

namespace Meteor.Navigation.Tests.Fixtures
{
    /// <summary>Writes .nav files (FORMATS §4) for tests. Production files come from navgen.</summary>
    sealed class NavFileWriter
    {
        public string Zone = "synthetic";
        public DtNavMeshParams Params;
        public float CellSize = 0.25f, CellHeight = 0.2f, WalkableHeight = 2.0f, WalkableClimb = 0.75f, WalkableRadius = 0.5f;
        public readonly List<(long tileRef, DtMeshData data)> Tiles = new List<(long, DtMeshData)>();
        public readonly List<NavAreaDef> Areas = new List<NavAreaDef>();
        public readonly List<NavGateDef> Gates = new List<NavGateDef>();
        public readonly List<NavLinkDef> Links = new List<NavLinkDef>();
        public readonly List<NavSeedDef> Seeds = new List<NavSeedDef>();
        public uint[] Islands;
        public NavGraphData Graph;
        /// <summary>Extra sections (fourcc → bytes) the reader must skip.</summary>
        public readonly List<(string fourcc, byte[] data)> Extra = new List<(string, byte[])>();

        public void Write(string path)
        {
            using (var f = File.Create(path))
                Write(f);
        }

        public void Write(Stream stream)
        {
            var sections = new List<(string, byte[])>
            {
                ("META", Json(w =>
                {
                    w.WriteString("zone", Zone);
                    w.WriteString("navgenVersion", "test");
                    w.WriteString("recastVersion", "DotRecast 2026.3.1");
                    w.WriteString("built", "2026-10-16T00:00:00Z");
                    w.WriteStartObject("effective");
                    w.WriteNumber("cs", CellSize);
                    w.WriteNumber("ch", CellHeight);
                    w.WriteNumber("walkableHeight", WalkableHeight);
                    w.WriteNumber("walkableClimb", WalkableClimb);
                    w.WriteNumber("walkableRadius", WalkableRadius);
                    w.WriteEndObject();
                })),
                ("PARM", Bin(w =>
                {
                    w.Write(Params.orig.X); w.Write(Params.orig.Y); w.Write(Params.orig.Z);
                    w.Write(Params.tileWidth); w.Write(Params.tileHeight);
                    w.Write(Params.maxTiles); w.Write(Params.maxPolys);
                })),
            };
            sections.AddRange(Extra);
            sections.Add(("TILE", Bin(w =>
            {
                w.Write((uint)Tiles.Count);
                var dw = new DtMeshDataWriter();
                foreach (var (tileRef, data) in Tiles)
                {
                    var ms = new MemoryStream();
                    using (var bw = new BinaryWriter(ms, Encoding.UTF8, true))
                        dw.Write(bw, data, RcByteOrder.LITTLE_ENDIAN, true);
                    byte[] bytes = ms.ToArray();
                    w.Write((ulong)tileRef);
                    w.Write((uint)bytes.Length);
                    w.Write(0u);
                    w.Write(bytes);
                    for (int i = bytes.Length; i % 8 != 0; i++)
                        w.Write((byte)0);
                }
            })));
            sections.Add(("AREA", JsonArray(Areas, (w, a) =>
            {
                w.WriteNumber("id", a.Id); w.WriteString("name", a.Name); w.WriteNumber("flags", a.Flags); w.WriteNumber("cost", a.Cost);
            })));
            sections.Add(("GATE", JsonArray(Gates, (w, g) =>
            {
                w.WriteNumber("index", g.Index); w.WriteString("id", g.Id); w.WriteString("kind", g.Kind); w.WriteString("default", g.Default);
                w.WriteStartObject("driver");
                foreach (var kv in g.Driver)
                    w.WriteString(kv.Key, kv.Value);
                w.WriteEndObject();
                w.WriteStartArray("polys");
                foreach (long p in g.Polys)
                    w.WriteStringValue("0x" + p.ToString("X"));
                w.WriteEndArray();
                w.WriteStartArray("links");
                foreach (int l in g.Links)
                    w.WriteNumberValue(l);
                w.WriteEndArray();
                w.WriteString("role", g.Role);
                if (g.Group != null) w.WriteString("group", g.Group);
            })));
            sections.Add(("LINK", JsonArray(Links, (w, l) =>
            {
                w.WriteNumber("index", l.Index); w.WriteString("id", l.Id); w.WriteString("kind", l.Kind);
                if (l.Gate >= 0) w.WriteNumber("gate", l.Gate); else w.WriteNull("gate");
                Vec(w, "a", l.A); Vec(w, "b", l.B);
                w.WriteBoolean("bidir", l.Bidir);
            })));
            sections.Add(("SEED", JsonArray(Seeds, (w, s) =>
            {
                w.WriteString("id", s.Id); Vec(w, "pos", s.Pos); w.WriteString("label", s.Label);
            })));
            if (Islands != null)
                sections.Add(("ISLD", Bin(w =>
                {
                    w.Write((uint)Islands.Length);
                    foreach (uint i in Islands)
                        w.Write(i);
                })));
            if (Graph != null)
                sections.Add(("GRPH", Bin(w =>
                {
                    w.Write(Graph.CellSize);
                    w.Write((uint)Graph.Nodes.Length);
                    w.Write((uint)Graph.Edges.Length);
                    w.Write((uint)Graph.PolyNode.Length);
                    foreach (var n in Graph.Nodes)
                    {
                        w.Write(n.CellX); w.Write(n.CellZ);
                        w.Write(n.Center.X); w.Write(n.Center.Y); w.Write(n.Center.Z);
                        w.Write((ulong)n.CenterPoly); w.Write(n.Gate); w.Write((uint)n.Island); w.Write((uint)n.Flags);
                    }
                    foreach (var e in Graph.Edges)
                    {
                        w.Write((uint)e.From); w.Write((uint)e.To); w.Write(e.Cost); w.Write(e.Gate); w.Write((uint)e.Flags);
                    }
                    foreach (int p in Graph.PolyNode)
                        w.Write(p < 0 ? 0xFFFFFFFFu : (uint)p);
                })));
            sections.Add(("VALD", Encoding.UTF8.GetBytes("{\"ok\":true}")));

            var w0 = new BinaryWriter(stream, Encoding.UTF8, true);
            long origin = stream.Position;
            w0.Write(NavFile.MAGIC);
            w0.Write(NavFile.VERSION);
            w0.Write(sections.Count);
            w0.Write(0u);
            long offset = Align8(16 + 24L * sections.Count);
            foreach (var (fourcc, data) in sections)
            {
                w0.Write(NavFile.FourCC(fourcc));
                w0.Write(0u);
                w0.Write((ulong)offset);
                w0.Write((ulong)data.Length);
                offset = Align8(offset + data.Length);
            }
            foreach (var (_, data) in sections)
            {
                while ((stream.Position - origin) % 8 != 0)
                    w0.Write((byte)0);
                w0.Write(data);
            }
            w0.Flush();
        }

        private static long Align8(long v) => (v + 7) & ~7L;

        private static byte[] Bin(Action<BinaryWriter> body)
        {
            var ms = new MemoryStream();
            using (var w = new BinaryWriter(ms))
                body(w);
            return ms.ToArray();
        }

        private static byte[] Json(Action<Utf8JsonWriter> body)
        {
            var ms = new MemoryStream();
            using (var w = new Utf8JsonWriter(ms))
            {
                w.WriteStartObject();
                body(w);
                w.WriteEndObject();
            }
            return ms.ToArray();
        }

        private static byte[] JsonArray<T>(IEnumerable<T> items, Action<Utf8JsonWriter, T> body)
        {
            var ms = new MemoryStream();
            using (var w = new Utf8JsonWriter(ms))
            {
                w.WriteStartArray();
                foreach (var item in items)
                {
                    w.WriteStartObject();
                    body(w, item);
                    w.WriteEndObject();
                }
                w.WriteEndArray();
            }
            return ms.ToArray();
        }

        private static void Vec(Utf8JsonWriter w, string name, Vector3 v)
        {
            w.WriteStartArray(name);
            w.WriteNumberValue(v.X); w.WriteNumberValue(v.Y); w.WriteNumberValue(v.Z);
            w.WriteEndArray();
        }
    }
}
