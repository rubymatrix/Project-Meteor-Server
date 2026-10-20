using System;
using System.Collections.Generic;
using System.IO;
using System.Numerics;
using System.Text.Json;

namespace Meteor.Navigation.Tests.Fixtures
{
    /// <summary>Synthetic collision (FORMATS §1 .xcol + groups.json) for CollisionWorld tests.</summary>
    sealed class XcolBuilder
    {
        private readonly List<float> verts = new List<float>();
        private readonly List<int> indices = new List<int>();
        private readonly List<ushort> group = new List<ushort>();
        private readonly List<byte> material = new List<byte>();
        private readonly List<byte> kind = new List<byte>();
        public readonly List<XcolGroup> Groups = new List<XcolGroup>();

        public XcolBuilder()
        {
            AddGroup("static");
        }

        public int AddGroup(string name, bool dynamic = false, string initial = "on", int kind = 1)
        {
            Groups.Add(new XcolGroup { Id = Groups.Count, Name = name, Kind = kind, Dynamic = dynamic, Initial = dynamic ? initial : null });
            return Groups.Count - 1;
        }

        public void Tri(Vector3 a, Vector3 b, Vector3 c, int group = 0, byte material = 0, byte kind = 1)
        {
            foreach (var p in new[] { a, b, c })
            {
                indices.Add(verts.Count / 3);
                verts.Add(p.X); verts.Add(p.Y); verts.Add(p.Z);
            }
            this.group.Add((ushort)group);
            this.material.Add(material);
            this.kind.Add(kind);
        }

        /// <summary>Horizontal rectangle at y, wound counter-clockwise seen from above (or from below with flip).</summary>
        public void Quad(float x0, float z0, float x1, float z1, float y, int group = 0, byte material = 0, byte kind = 1, bool flip = false)
        {
            var a = new Vector3(x0, y, z0); var b = new Vector3(x1, y, z0);
            var c = new Vector3(x1, y, z1); var d = new Vector3(x0, y, z1);
            if (flip)
            {
                Tri(a, b, c, group, material, kind);
                Tri(a, c, d, group, material, kind);
            }
            else
            {
                Tri(a, c, b, group, material, kind);
                Tri(a, d, c, group, material, kind);
            }
        }

        /// <summary>Vertical wall along x = x0 from z0 to z1.</summary>
        public void WallX(float x0, float z0, float z1, float y0, float y1, int group = 0)
        {
            Tri(new Vector3(x0, y0, z0), new Vector3(x0, y0, z1), new Vector3(x0, y1, z1), group);
            Tri(new Vector3(x0, y0, z0), new Vector3(x0, y1, z1), new Vector3(x0, y1, z0), group);
        }

        public XcolFile File() => XcolReader.Parse(Bytes(), "synthetic");

        public CollisionWorld World(string name = "synthetic")
        {
            var x = File();
            x.Groups = XcolReader.ReadGroups(GroupsJson());
            return new CollisionWorld(name, new[] { (name, x) });
        }

        public byte[] Bytes()
        {
            var ms = new MemoryStream();
            var w = new BinaryWriter(ms);
            int nv = verts.Count / 3, nt = group.Count;
            w.Write(XcolReader.MAGIC); w.Write(XcolReader.VERSION);
            w.Write(nv); w.Write(nt); w.Write(Groups.Count);
            w.Write(new byte[12]);
            var lo = new Vector3(float.MaxValue); var hi = new Vector3(float.MinValue);
            for (int i = 0; i < nv; i++)
            {
                var p = new Vector3(verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2]);
                lo = Vector3.Min(lo, p); hi = Vector3.Max(hi, p);
            }
            if (nv == 0) lo = hi = Vector3.Zero;
            w.Write(lo.X); w.Write(lo.Y); w.Write(lo.Z); w.Write(hi.X); w.Write(hi.Y); w.Write(hi.Z);
            foreach (float f in verts) w.Write(f);
            for (int t = 0; t < nt; t++)
            {
                w.Write((uint)indices[t * 3]); w.Write((uint)indices[t * 3 + 1]); w.Write((uint)indices[t * 3 + 2]);
                w.Write(group[t]); w.Write(material[t]); w.Write(kind[t]);
            }
            return ms.ToArray();
        }

        public string GroupsJson()
        {
            var ms = new MemoryStream();
            using (var w = new Utf8JsonWriter(ms))
            {
                w.WriteStartObject();
                w.WriteNumber("version", 1);
                w.WriteStartArray("groups");
                foreach (var g in Groups)
                {
                    w.WriteStartObject();
                    w.WriteNumber("id", g.Id);
                    w.WriteString("name", g.Name);
                    w.WriteNumber("kind", g.Kind);
                    if (g.Dynamic)
                    {
                        w.WriteStartObject("dynamic");
                        w.WriteString("initial", g.Initial);
                        w.WriteEndObject();
                    }
                    else
                        w.WriteNull("dynamic");
                    w.WriteEndObject();
                }
                w.WriteEndArray();
                w.WriteEndObject();
            }
            return System.Text.Encoding.UTF8.GetString(ms.ToArray());
        }
    }
}
