using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Text.Json;
using Xunit;

namespace Meteor.Navigation.Tests
{
    /// <summary>
    /// Checks against navgen's own fixture (navgen-test --write-fixture: synthetic.nav plus
    /// synthetic.expected.json) when it exists next to this repo, or under $NAVGEN_FIXTURES. Each test
    /// passes trivially without it so the suite never depends on a navgen build.
    /// </summary>
    public class NavgenFixtureTests
    {
        // the fixture's snap probes (expected.json "description")
        private const float PROBE_RADIUS = 0.5f, PROBE_VERTICAL = 1.0f;

        private sealed class Fixture
        {
            public NavWorld World;
            public JsonElement Expected;
            public Dictionary<string, Vector3> Points = new Dictionary<string, Vector3>();
        }

        private static readonly Lazy<Fixture> fixture = new Lazy<Fixture>(Load);

        internal static string FixtureDir()
        {
            string env = Environment.GetEnvironmentVariable("NAVGEN_FIXTURES");
            if (!string.IsNullOrEmpty(env))
                return Directory.Exists(env) ? env : null;
            for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
            {
                string candidate = Path.Combine(dir.FullName, "navgen", "build", "fixtures");
                if (File.Exists(Path.Combine(candidate, "synthetic.expected.json")))
                    return candidate;
            }
            return null;
        }

        private static Fixture Load()
        {
            string dir = FixtureDir();
            if (dir == null)
                return null;
            var f = new Fixture();
            f.Expected = JsonDocument.Parse(File.ReadAllText(Path.Combine(dir, "synthetic.expected.json"))).RootElement;
            string nav = f.Expected.TryGetProperty("nav", out var n) ? n.GetString() : "synthetic.nav";
            f.World = NavWorld.Load(Path.Combine(dir, nav));
            foreach (var p in f.Expected.GetProperty("points").EnumerateObject())
                f.Points[p.Name] = new Vector3(p.Value[0].GetSingle(), p.Value[1].GetSingle(), p.Value[2].GetSingle());
            return f;
        }

        private static NavAgent Agent(string name) => name == "mob" ? NavAgent.Mob : NavAgent.Player;

        /// <summary>An instance with exactly these gates closed (the fixture lists closed ones; the rest are open).</summary>
        private static NavInstance With(Fixture f, JsonElement closed)
        {
            var inst = f.World.CreateInstance("fixture");
            var shut = closed.EnumerateArray().Select(c => c.GetString()).ToHashSet();
            for (int g = 0; g < f.World.Gates.Count; g++)
                inst.SetGate(g, !shut.Contains(f.World.Gates[g].Id));
            return inst;
        }

        private static NavPoint Probe(NavInstance inst, Vector3 p) => inst.Project(p, NavAgent.Player, PROBE_VERTICAL, PROBE_RADIUS);

        [Fact]
        public void LoadsWithExpectedCounts()
        {
            var f = fixture.Value;
            if (f == null)
                return;
            var counts = f.Expected.GetProperty("counts");
            Assert.Empty(f.World.Warnings);
            Assert.Equal(counts.GetProperty("tiles").GetInt32(), f.World.TileCount);
            Assert.Equal(counts.GetProperty("polys").GetInt32(), f.World.PolyCount);
            Assert.NotNull(f.World.Graph);
            Assert.Equal(counts.GetProperty("graphNodes").GetInt32(), f.World.Graph.Nodes.Length);
            Assert.Equal(counts.GetProperty("graphEdges").GetInt32(), f.World.Graph.Edges.Length);
            var eff = f.Expected.GetProperty("effective");
            Assert.Equal(eff.GetProperty("walkableRadius").GetSingle(), f.World.BakedRadius, 3);
        }

        [Fact]
        public void GatesAndLinksMatch()
        {
            var f = fixture.Value;
            if (f == null)
                return;
            foreach (var g in f.Expected.GetProperty("gates").EnumerateObject())
            {
                int index = f.World.GateIndex(g.Name);
                Assert.Equal(g.Value.GetProperty("index").GetInt32(), index);
                var def = f.World.Gates[index];
                Assert.Equal(g.Value.GetProperty("default").GetString(), def.Default);
                Assert.Equal(g.Value.GetProperty("polys").GetInt32(), def.Polys.Length);
                Assert.Equal(g.Value.GetProperty("links").EnumerateArray().Select(l => l.GetInt32()), def.Links);
            }
            foreach (var l in f.Expected.GetProperty("links").EnumerateArray())
            {
                var link = f.World.Links[l.GetProperty("index").GetInt32()];
                Assert.Equal(l.GetProperty("id").GetString(), link.Id);
                Assert.Equal(l.GetProperty("bidir").GetBoolean(), link.Bidir);
                Assert.Equal(l.GetProperty("gate").GetInt32(), link.Gate);
            }
        }

        [Fact]
        public void PointsHaveExpectedAreaGateAndPruning()
        {
            var f = fixture.Value;
            if (f == null)
                return;
            var inst = With(f, JsonDocument.Parse("[]").RootElement);
            var areas = f.Expected.GetProperty("areas");
            var gates = f.Expected.GetProperty("pointGate");
            foreach (var pruned in f.Expected.GetProperty("pruned").EnumerateObject())
            {
                var p = Probe(inst, f.Points[pruned.Name]);
                if (pruned.Value.GetBoolean())
                {
                    Assert.False(p.Ok, $"{pruned.Name} should be pruned");
                    continue;
                }
                Assert.True(p.Ok, $"{pruned.Name}: {p.Reason}");
                string area = areas.GetProperty(pruned.Name).GetString();
                var def = f.World.Areas.FirstOrDefault(a => a.Name == area);
                Assert.NotNull(def);
                Assert.Equal(def.Id, f.World.PolyArea(p.Poly));
                var gate = gates.GetProperty(pruned.Name);
                int g = f.World.GateOfPoly(p.Poly);
                if (gate.ValueKind == JsonValueKind.Null)
                    Assert.Equal(-1, g);
                else
                    Assert.Equal(gate.GetString(), f.World.Gates[g].Id);
            }
        }

        [Fact]
        public void ReachabilityMatrix()
        {
            var f = fixture.Value;
            if (f == null)
                return;
            var failures = new List<string>();
            foreach (var r in f.Expected.GetProperty("reach").EnumerateArray())
            {
                var inst = With(f, r.GetProperty("closed"));
                string from = r.GetProperty("from").GetString(), to = r.GetProperty("to").GetString();
                var got = inst.Reachable(f.Points[from], f.Points[to], Agent(r.GetProperty("agent").GetString()), PROBE_VERTICAL, PROBE_RADIUS);
                if (got.Reachable != r.GetProperty("expect").GetBoolean())
                    failures.Add($"{r.GetProperty("agent").GetString()} {from}->{to} closed [{string.Join(",", r.GetProperty("closed").EnumerateArray())}]: {got}");
            }
            Assert.Empty(failures);
        }

        [Fact]
        public void PathsMatchStatusAndLength()
        {
            var f = fixture.Value;
            if (f == null)
                return;
            var failures = new List<string>();
            foreach (var p in f.Expected.GetProperty("paths").EnumerateArray())
            {
                var inst = With(f, p.GetProperty("closed"));
                string from = p.GetProperty("from").GetString(), to = p.GetProperty("to").GetString();
                var route = inst.PlanRoute(f.Points[from], f.Points[to], Agent(p.GetProperty("agent").GetString()),
                    new RouteOpts { MaxVertical = PROBE_VERTICAL, SearchRadius = PROBE_RADIUS });
                float length = route.Length;
                for (int guard = 0; route.Ok && !route.Complete && guard < 20; guard++)
                {
                    var last = route.Points[route.Points.Count - 1];
                    route.Advance(last);
                    length += route.Length;
                }
                bool full = p.GetProperty("status").GetString() == "full";
                string label = $"{from}->{to} closed [{string.Join(",", p.GetProperty("closed").EnumerateArray())}]";
                if (full != (route.Reason == NavReason.Ok && route.Complete))
                    failures.Add($"{label}: {route}");
                else if (full && Math.Abs(length - p.GetProperty("length").GetSingle()) > 0.1f * p.GetProperty("length").GetSingle() + 1.0f)
                    failures.Add($"{label}: length {length:F2}, navgen {p.GetProperty("length").GetSingle():F2}");
            }
            Assert.Empty(failures);
        }
    }
}
