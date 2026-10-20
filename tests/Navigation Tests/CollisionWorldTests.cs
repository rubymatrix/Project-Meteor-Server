using System;
using System.IO;
using System.Linq;
using System.Numerics;
using Meteor.Navigation.Tests.Fixtures;
using Xunit;
using S = Meteor.Navigation.Tests.Fixtures.SyntheticScene;

namespace Meteor.Navigation.Tests
{
    /// <summary>CollisionWorld on synthetic geometry: the client's ground probe rules (ClientProbe).</summary>
    public class CollisionWorldTests
    {
        private static CollisionWorld Floor(Action<XcolBuilder> more = null)
        {
            var b = new XcolBuilder();
            b.Quad(-20, -20, 20, 20, 0);
            more?.Invoke(b);
            return b.World();
        }

        #region Reader

        [Fact]
        public void ReaderRoundTrip()
        {
            var b = new XcolBuilder();
            int door = b.AddGroup("sgrp_door@1", dynamic: true, initial: "off");
            b.Quad(0, 0, 1, 1, 3, door, material: 5, kind: 2);
            var x = b.File();
            Assert.Equal(2, x.TriangleCount);
            Assert.Equal(6, x.VertexCount);
            Assert.Equal(new Vector3(0, 3, 0), x.BoundsMin);
            Assert.Equal(new Vector3(1, 3, 1), x.BoundsMax);
            Assert.Equal(door, x.Group[0]);
            Assert.Equal(5, x.Material[1]);
            Assert.Equal(2, x.Kind[1]);

            var groups = XcolReader.ReadGroups(b.GroupsJson());
            Assert.Equal(2, groups.Count);
            Assert.False(groups[0].Dynamic);
            Assert.Null(groups[0].Initial);
            Assert.True(groups[1].Dynamic);
            Assert.Equal("off", groups[1].Initial);
            Assert.Equal("sgrp_door@1", groups[1].Name);
        }

        [Fact]
        public void ReaderRejectsBadFiles()
        {
            var bytes = new XcolBuilder().Bytes();
            bytes[0] = (byte)'Y';
            Assert.Throws<InvalidDataException>(() => XcolReader.Parse(bytes));
            Assert.Throws<InvalidDataException>(() => XcolReader.Parse(new XcolBuilder().Bytes().AsSpan(0, 40).ToArray()));
        }

        [Fact]
        public void LoadZonesReadsAFolder()
        {
            string dir = Path.Combine(Path.GetTempPath(), "xcol-test-" + Guid.NewGuid().ToString("N"), "zoneA");
            Directory.CreateDirectory(dir);
            try
            {
                var b = new XcolBuilder();
                b.Quad(0, 0, 4, 4, 1.5f);
                File.WriteAllBytes(Path.Combine(dir, "static.xcol"), b.Bytes());
                File.WriteAllText(Path.Combine(dir, "groups.json"), b.GroupsJson());
                var w = CollisionWorld.LoadZones("zoneA", dir);
                Assert.Equal(2, w.TriangleCount);
                Assert.Equal("zoneA", w.Groups[0].Zone);
                Assert.Equal(1.5f, w.Probe(2, 2, 1).Y);
            }
            finally
            {
                Directory.Delete(Path.GetDirectoryName(dir), true);
            }
        }

        #endregion

        #region Probe window

        [Fact]
        public void ProbeWindowIsTwoUpTenDown()
        {
            var w = Floor();
            Assert.Equal(0f, w.Probe(1, 1, 0).Y);
            Assert.Equal(0f, w.Probe(1, 1, -2).Y);      // floor exactly at y + 2: the ray starts on it
            Assert.False(w.Probe(1, 1, -2.01f).Hit);    // floor above the ray start
            Assert.Equal(0f, w.Probe(1, 1, 9.99f).Y);
            Assert.False(w.Probe(1, 1, 10).Hit);        // t == length is past the end of the ray
            Assert.False(w.Probe(30, 30, 0).Hit);       // nothing under it
        }

        [Fact]
        public void ProbeTakesTheNearestSurfaceBelowTheRayStart()
        {
            float up = 0.75f * ClientProbe.RayUp;
            var w = Floor(b => b.Quad(2, -2, 4, 2, up));
            Assert.Equal(up, w.Probe(3, 0, 0).Y);       // an overhang under the ray start is what the client stands on
            Assert.Equal(0f, w.Probe(3, 0, up - ClientProbe.RayUp - 0.1f).Y);   // ray starts just under it
            Assert.Equal(0f, w.Probe(1, 0, 0).Y);
        }

        [Fact]
        public void Overhang()
        {
            var w = Floor(b => b.Quad(2, -2, 4, 2, 1.8f));
            Assert.False(w.Headroom(3, 0, 0, 2));
            Assert.True(w.Headroom(3, 0, 0, 1.7f));
            Assert.True(w.Headroom(1, 0, 0, 2));
            Assert.True(w.Headroom(3, 0, 1.8f, 2));     // standing on top of it
            Assert.Equal(new[] { 1.8f, 0f }, w.Floors(3, 0).Select(h => h.Y));
        }

        [Fact]
        public void Step()
        {
            var w = Floor(b =>
            {
                b.Quad(5, -2, 7, 2, ClientProbe.RayUp);
                b.Quad(8, -2, 10, 2, ClientProbe.RayUp + 0.01f);
            });
            Assert.Equal(ClientProbe.RayUp, w.Probe(6, 0, 0).Y);   // rise of exactly RayUp: still seen
            Assert.Equal(0f, w.Probe(9, 0, 0).Y);       // rise past it: the ray starts under it, finds the floor
        }

        [Fact]
        public void Gap()
        {
            var b = new XcolBuilder();
            b.Quad(0, -2, 5, 2, 0);
            b.Quad(6, -2, 10, 2, 0);
            b.Quad(5, -2, 6, 2, -10.5f);
            var w = b.World();
            Assert.False(w.Probe(5.5f, 0, 0).Hit);      // the pit floor is past the 10 down
            Assert.Equal(-10.5f, w.Probe(5.5f, 0, -1).Y);
            Assert.Equal(0f, w.Probe(5, 0, 0).Y);       // the shared edge belongs to the floor
        }

        [Fact]
        public void WallsAreInvisibleToTheDownRay()
        {
            var w = Floor(b => b.WallX(3, -5, 5, 0, 4));
            Assert.Equal(2, w.TriangleCount);           // the wall has no XZ area and is dropped
            Assert.Equal(0f, w.Probe(3, 0, 1).Y);
        }

        [Fact]
        public void BackFacesAreHit()
        {
            var b = new XcolBuilder();
            b.Quad(0, 0, 4, 4, 1.0f, flip: true);
            var w = b.World();
            Assert.Equal(1.0f, w.Probe(2, 2, 0).Y);
        }

        [Fact]
        public void SlopedTriangle()
        {
            var b = new XcolBuilder();
            b.Tri(new Vector3(0, 0, 0), new Vector3(0, 0, 10), new Vector3(10, 5, 0));
            var w = b.World();
            Assert.Equal(2.5f, w.Probe(5, 0, 2).Y, 4);
            Assert.Equal(1.0f, w.Probe(2, 4, 0).Y, 4);
        }

        #endregion

        #region Visibility

        [Theory]
        [InlineData(0, 1, true)]
        [InlineData(1, 1, true)]
        [InlineData(4, 1, true)]
        [InlineData(5, 16, true)]
        [InlineData(120, 1, true)]
        [InlineData(2, 1, false)]
        [InlineData(3, 1, false)]
        [InlineData(6, 1, false)]
        [InlineData(7, 16, false)]
        [InlineData(0, 2, false)]
        [InlineData(5, 2, false)]
        public void MaterialAndKindDecideVisibility(int material, int kind, bool visible)
        {
            var b = new XcolBuilder();
            b.Quad(0, 0, 4, 4, 0);
            b.Quad(0, 0, 4, 4, 1, material: (byte)material, kind: (byte)kind);
            var w = b.World();
            Assert.Equal(visible ? 1f : 0f, w.Probe(2, 2, 0).Y);
            Assert.Equal(visible ? 4 : 2, w.TriangleCount);
        }

        [Fact]
        public void WaterPlaneOverFloorIsSeeThrough()
        {
            var w = Floor(b => b.Quad(-5, -5, 5, 5, 1.2f, material: 6));
            Assert.Equal(0f, w.Probe(0, 0, 1.2f).Y);
            Assert.True(w.Headroom(0, 0, 0, 2));
        }

        #endregion

        #region Switchable groups

        [Fact]
        public void DynamicGroupToggles()
        {
            int door = 0, hidden = 0;
            var w = Floor(b =>
            {
                door = b.AddGroup("sgrp_door@1", dynamic: true, initial: "on");
                hidden = b.AddGroup("sgrp_bridge@2", dynamic: true, initial: "off");
                b.Quad(0, 0, 2, 2, 1.0f, door);
                b.Quad(4, 0, 6, 2, 0.5f, hidden);
            });
            Assert.Equal(2, w.DynamicGroups.Count);
            int doorSlot = w.DynamicSlot("sgrp_door@1"), bridgeSlot = w.DynamicSlot("sgrp_bridge@2");
            Assert.Equal(-1, w.DynamicSlot("static"));

            var hit = w.Probe(1, 1, 0);
            Assert.Equal(1.0f, hit.Y);
            Assert.Equal("sgrp_door@1", w.GroupOf(hit).Name);
            Assert.Equal(0f, w.Probe(5, 1, 0).Y);                          // starts off

            var s = w.Defaults.With(doorSlot, false).With(bridgeSlot, true);
            Assert.Equal(0f, w.Probe(1, 1, 0, s).Y);
            Assert.Equal(0.5f, w.Probe(5, 1, 0, s).Y);
            Assert.True(w.Headroom(1, 1, 0, 2, s));
            Assert.False(w.Headroom(1, 1, 0, 2));
            Assert.Equal(0f, w.Probe(1, 1, 0, s.With(doorSlot, false)).Y);  // no-op change
            Assert.Same(s, s.With(doorSlot, false));
        }

        [Fact]
        public void DynamicGroupsFollowNavGates()
        {
            var scene = S.Build();
            scene.Writer.Gates[S.GATE_DOOR].Group = "sgrp_door@1";              // block: present while closed
            scene.Writer.Gates[S.GATE_WALL].Id = "auto:sgrp_bridge@2";
            scene.Writer.Gates[S.GATE_WALL].Role = "surface";                   // surface: present while open
            string path = Path.Combine(Path.GetTempPath(), "collision-gates-" + Guid.NewGuid().ToString("N") + ".nav");
            try
            {
                scene.Writer.Write(path);
                var nav = NavWorld.Load(path);
                Assert.Equal("sgrp_door@1", nav.Gates[S.GATE_DOOR].Group);

                var w = Floor(b =>
                {
                    b.Quad(0, 0, 2, 2, 1.0f, b.AddGroup("sgrp_door@1", dynamic: true, initial: "on"));
                    b.Quad(4, 0, 6, 2, 0.5f, b.AddGroup("sgrp_bridge@2", dynamic: true, initial: "off"));
                    b.Quad(8, 0, 10, 2, 0.7f, b.AddGroup("sgrp_unbound@3", dynamic: true, initial: "on"));
                });
                Assert.Equal(2, w.BoundGates(nav));

                var inst = nav.CreateInstance("test");                          // every gate open by default
                var open = w.StateFor(inst);
                Assert.Equal(0f, w.Probe(1, 1, 0, open).Y);
                Assert.Equal(0.5f, w.Probe(5, 1, 0, open).Y);
                Assert.Equal(0.7f, w.Probe(9, 1, 0, open).Y);
                Assert.Same(open, w.StateFor(inst));

                inst.SetGate(S.GATE_DOOR, false);
                inst.SetGate(S.GATE_WALL, false);
                var closed = w.StateFor(inst);
                Assert.NotSame(open, closed);
                Assert.Equal(1.0f, w.Probe(1, 1, 0, closed).Y);
                Assert.Equal(0f, w.Probe(5, 1, 0, closed).Y);
                Assert.Equal(0.7f, w.Probe(9, 1, 0, closed).Y);

                Assert.Same(w.Defaults, w.StateFor(null));
            }
            finally
            {
                File.Delete(path);
            }
        }

        #endregion

        #region Scale

        [Fact]
        public void ManyTrianglesMatchBruteForce()
        {
            var rng = new Random(7);
            var b = new XcolBuilder();
            var tris = new (Vector3 a, Vector3 b, Vector3 c)[3000];
            for (int i = 0; i < tris.Length; i++)
            {
                var o = new Vector3(rng.NextSingle() * 100, rng.NextSingle() * 30, rng.NextSingle() * 100);
                Vector3 R() => new Vector3(rng.NextSingle() * 6 - 3, rng.NextSingle() * 2 - 1, rng.NextSingle() * 6 - 3);
                tris[i] = (o + R(), o + R(), o + R());
                b.Tri(tris[i].a, tris[i].b, tris[i].c);
            }
            var w = b.World();
            for (int q = 0; q < 2000; q++)
            {
                float x = rng.NextSingle() * 100, z = rng.NextSingle() * 100, y = rng.NextSingle() * 34 - 2;
                float best = float.NegativeInfinity;
                foreach (var t in tris)
                    if (Column(t.a, t.b, t.c, x, z, out float ty) && ty <= y + ClientProbe.RayUp && ty > y - ClientProbe.RayDown)
                        best = Math.Max(best, ty);
                var hit = w.Probe(x, z, y);
                Assert.Equal(!float.IsNegativeInfinity(best), hit.Hit);
                if (hit.Hit)
                    Assert.Equal(best, hit.Y);
            }
        }

        private static bool Column(Vector3 a, Vector3 b, Vector3 c, float x, float z, out float y)
        {
            double v0x = b.X - a.X, v0z = b.Z - a.Z, v1x = c.X - a.X, v1z = c.Z - a.Z, px = x - a.X, pz = z - a.Z;
            double den = v0x * v1z - v1x * v0z;
            y = 0;
            if (den == 0)
                return false;
            double u = (px * v1z - v1x * pz) / den, v = (v0x * pz - px * v0z) / den;
            if (u < -1e-7 || v < -1e-7 || u + v > 1 + 1e-7)
                return false;
            y = (float)(a.Y + u * (b.Y - a.Y) + v * (c.Y - a.Y));
            return true;
        }

        #endregion
    }
}
