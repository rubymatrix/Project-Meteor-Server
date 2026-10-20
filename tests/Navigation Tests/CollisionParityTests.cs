using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Navigation.Tests
{
    /// <summary>
    /// Local only: CollisionWorld against an offline model of the client's probe over the real collision
    /// export. METEOR_PROBE_PARITY names a JSON of {zones: [...], queries: [{x, z, y, hit}]}; the zones are
    /// read from METEOR_COLLISION (or the workspace's collision/ folder). Skipped when either is missing,
    /// since the collision export is client data and never committed.
    /// </summary>
    public class CollisionParityTests
    {
        private readonly ITestOutputHelper output;

        public CollisionParityTests(ITestOutputHelper output)
        {
            this.output = output;
        }

        internal static string CollisionDir()
        {
            string env = Environment.GetEnvironmentVariable("METEOR_COLLISION");
            if (!string.IsNullOrEmpty(env))
                return Directory.Exists(env) ? env : null;
            for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
            {
                string candidate = Path.Combine(dir.FullName, "collision");
                if (File.Exists(Path.Combine(candidate, "zones.json")))
                    return candidate;
            }
            return null;
        }

        [Fact]
        public void ProbeMatchesOfflineModel()
        {
            string expected = Environment.GetEnvironmentVariable("METEOR_PROBE_PARITY");
            string dir = CollisionDir();
            if (string.IsNullOrEmpty(expected) || !File.Exists(expected) || dir == null)
                return;

            using var doc = JsonDocument.Parse(File.ReadAllText(expected));
            var zones = doc.RootElement.GetProperty("zones").EnumerateArray().Select(z => Path.Combine(dir, z.GetString())).ToArray();
            var world = CollisionWorld.LoadZones("parity", zones);

            int n = 0, hits = 0;
            var bad = new List<string>();
            foreach (var q in doc.RootElement.GetProperty("queries").EnumerateArray())
            {
                float x = q.GetProperty("x").GetSingle(), z = q.GetProperty("z").GetSingle(), y = q.GetProperty("y").GetSingle();
                var want = q.GetProperty("hit");
                var got = world.Probe(x, z, y);
                n++;
                bool wantHit = want.ValueKind == JsonValueKind.Number;
                if (wantHit)
                    hits++;
                if (wantHit != got.Hit || (wantHit && Math.Abs(want.GetDouble() - got.Y) > 1e-4))
                    bad.Add($"({x}, {y}, {z}): want {(wantHit ? want.GetDouble().ToString("F4") : "miss")}, got {got} {world.GroupOf(got)}");
            }
            output.WriteLine($"{n} probes, {hits} hits, {bad.Count} mismatches; {world.TriangleCount} of {world.SourceTriangles} triangles kept");
            foreach (var b in bad.Take(20))
                output.WriteLine(b);
            Assert.Empty(bad);
        }
    }
}
