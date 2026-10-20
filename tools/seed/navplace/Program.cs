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
using System.Linq;
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Nodes;
using DotRecast.Core.Numerics;
using DotRecast.Detour;
using Meteor.Navigation;

namespace Meteor.Tools.NavPlace
{
    /// <summary>
    /// navplace in.json out.json: for each spawn group, finds the walkable ground for its approximate
    /// rows (x/z from a map spot or a zone centroid, height unknown).
    ///
    ///   in:  { "navDir": "...", "arrivalDir": "...", "groups": [ { "group", "zone", "radius",
    ///          "placed": [[x,y,z]...], "rows": [ { "id", "x", "y", "z", "current": [x,y,z]?, "fallback": bool? } ] } ] }
    ///   out: { "meshes": { zone: file }, "rows": { id: { "x","y","z","moved","how","fallback"? } },
    ///          "unplaced": [ { "id", "zone", "reason", "nearest" } ], "noArrivals": [ zone ] }
    ///
    /// Only ground a player can walk to from the zone's arrival points counts (aetherytes, entrances
    /// and seamless crossings from arrivalDir/&lt;zone&gt;.json, Player agent, every gate open: the rule
    /// navgen validate uses, https://github.com/rubymatrix/navgen/blob/main/docs/FORMATS.md "Arrival points"). A row whose "current" spot is
    /// still such ground stays there. The rest of the group: its anchor (its placed and kept rows'
    /// centre, else its approximate rows' centre) goes on the largest island found within "radius" of
    /// it (islands at least half its size count too), at the candidate nearest the anchor; each row
    /// keeps its offset from the anchor when that ground is on the same island and reachable, else
    /// moves in towards it. No row moves further than "radius". Mob agent, no water, all gates open.
    /// A row with "fallback" that has no such ground within "radius" goes to the nearest one at any
    /// distance instead (its group's anchor there, the row at its offset when that ground allows), and
    /// is marked "fallback"; every other such row is unplaced, with the distance to that ground.
    /// A zone without arrival points that snap is placed without the arrival rule and listed in
    /// "noArrivals". Deterministic.
    /// </summary>
    static class Program
    {
        private static readonly float[] Radii = { 0, 4, 8, 12, 16, 24, 32, 48, 64, 80, 100, 128, 160, 200 };
        private const float MEMBER_SLACK = 2.0f;   // a member's ground may be this far (XZ) from where it asked
        private const float KEEP_SLACK = 0.5f;     // a kept row's spot must snap back within this (XZ)

        private sealed class Zone
        {
            public NavWorld World;
            public NavInstance Instance;
            public Dictionary<int, int> IslandPolys;
            public string File;
            /// <summary>Arrival points snapped for the Player agent; empty = no arrival rule.</summary>
            public List<Vector3> Arrivals;
            /// <summary>Per component-graph node (or per poly without a graph): reached from an arrival point.</summary>
            public Dictionary<long, bool> ReachedCache;
        }

        private struct Ground
        {
            public Vector3 Pos;
            public int Island;
            public bool Ok;
            public bool Reached;
        }

        static int Main(string[] args)
        {
            if (args.Length != 2)
            {
                Console.Error.WriteLine("usage: navplace in.json out.json");
                return 2;
            }
            var input = JsonNode.Parse(File.ReadAllText(args[0]));
            string navDir = (string)input["navDir"];
            string arrivalDir = (string)input["arrivalDir"];
            var manifest = NavManifest.Load(Path.Combine(navDir, "manifest.json"));
            var zones = new Dictionary<string, Zone>(StringComparer.OrdinalIgnoreCase);
            var rowsOut = new JsonObject();
            var unplaced = new JsonArray();
            var meshes = new JsonObject();
            var noArrivals = new SortedSet<string>(StringComparer.Ordinal);

            foreach (var g in input["groups"].AsArray())
            {
                string zoneName = (string)g["zone"];
                var allRows = g["rows"].AsArray().Select(r => (id: (long)r["id"], p: new Vector3((float)r["x"], (float)r["y"], (float)r["z"]),
                    cur: r["current"] is JsonArray c ? new Vector3((float)c[0], (float)c[1], (float)c[2]) : (Vector3?)null)).ToList();
                var fallbackIds = new HashSet<long>(g["rows"].AsArray().Where(r => (bool?)r["fallback"] == true).Select(r => (long)r["id"]));
                var zone = LoadZone(zones, manifest, zoneName, arrivalDir);
                if (zone == null)
                {
                    foreach (var r in allRows)
                        unplaced.Add(new JsonObject { ["id"] = r.id, ["zone"] = zoneName, ["reason"] = "no .nav world" });
                    continue;
                }
                meshes[zoneName] = Path.GetFileName(zone.File);
                if (zone.Arrivals.Count == 0)
                    noArrivals.Add(zoneName);

                var placed = g["placed"]?.AsArray().Select(p => new Vector3((float)p[0], (float)p[1], (float)p[2])).ToList() ?? new List<Vector3>();

                // rows whose current spot is still dry mob ground a player can reach stay put
                var rows = new List<(long id, Vector3 p)>();
                string noGround = $"no dry mob ground reached from arrival points within {(float)g["radius"]:0}y";
                foreach (var r in allRows)
                {
                    var kept = r.cur.HasValue ? Snap(zone, r.cur.Value) : default;
                    if (kept.Ok && Flat(kept.Pos, r.cur.Value) <= KEEP_SLACK && MathF.Abs(kept.Pos.Y - r.cur.Value.Y) <= 1.0f && kept.Reached)
                    {
                        var c = r.cur.Value;
                        rowsOut[r.id.ToString()] = new JsonObject
                        {
                            ["x"] = Math.Round(c.X, 1),
                            ["y"] = Math.Round(c.Y, 1),
                            ["z"] = Math.Round(c.Z, 1),
                            ["moved"] = Math.Round(Flat(c, r.p), 1),
                            ["how"] = "kept",
                        };
                        placed.Add(c);
                    }
                    else
                    {
                        rows.Add((r.id, r.p));
                    }
                }
                if (rows.Count == 0)
                    continue;
                var basis = placed.Count > 0 ? placed : rows.Select(r => r.p).ToList();
                var anchor = new Vector3(basis.Average(p => p.X), basis.Average(p => p.Y), basis.Average(p => p.Z));
                float radius = (float)g["radius"];

                Ground home = placed.Count > 0 ? IslandOfPlaced(zone, placed) : default;
                if (!home.Ok)
                    home = BestNear(zone, anchor, radius);
                bool fallback = false;
                if (!home.Ok)
                {
                    foreach (var r in rows.Where(r => !fallbackIds.Contains(r.id)))
                        unplaced.Add(Unplaced(zone, r.id, r.p, zoneName, noGround));
                    rows = rows.Where(r => fallbackIds.Contains(r.id)).ToList();
                    if (rows.Count == 0)
                        continue;
                    home = Nearest(zone, anchor);
                    fallback = true;
                    if (!home.Ok)
                    {
                        foreach (var r in rows)
                        {
                            var u = Unplaced(zone, r.id, r.p, zoneName, "no dry mob ground reached from arrival points");
                            u["fallback"] = true;
                            unplaced.Add(u);
                        }
                        continue;
                    }
                }

                // keep the group's shape around its new anchor
                var center = rows.Count > 0 ? new Vector3(rows.Average(r => r.p.X), 0, rows.Average(r => r.p.Z)) : anchor;
                foreach (var r in rows)
                {
                    var offset = new Vector2(r.p.X - center.X, r.p.Z - center.Z);
                    Ground spot = default;
                    string how = "offset";
                    foreach (float scale in new[] { 1.0f, 0.5f, 0.25f })
                    {
                        var want = new Vector3(home.Pos.X + offset.X * scale, home.Pos.Y, home.Pos.Z + offset.Y * scale);
                        var gnd = Snap(zone, want);
                        if (gnd.Ok && gnd.Reached && gnd.Island == home.Island && Flat(gnd.Pos, want) <= MEMBER_SLACK
                            && Reachable(zone, home.Pos, gnd.Pos))
                        {
                            spot = gnd;
                            how = scale == 1.0f ? "offset" : "offset x" + scale;
                            break;
                        }
                    }
                    bool rowFallback = fallback;
                    if (!spot.Ok && (fallback || Flat(home.Pos, r.p) <= radius))
                    {
                        spot = home;
                        how = "anchor";
                    }
                    // a row far out in a spread group: its own nearest big ground, never past its error radius
                    if (!fallback && (!spot.Ok || Flat(spot.Pos, r.p) > radius))
                    {
                        spot = BestNear(zone, r.p, radius);
                        how = "own";
                        if (!spot.Ok && fallbackIds.Contains(r.id))
                        {
                            spot = Nearest(zone, r.p);
                            rowFallback = true;
                        }
                    }
                    if (!spot.Ok)
                    {
                        var u = Unplaced(zone, r.id, r.p, zoneName, noGround);
                        if (rowFallback)
                            u["fallback"] = true;
                        unplaced.Add(u);
                        continue;
                    }
                    var row = new JsonObject
                    {
                        ["x"] = Math.Round(spot.Pos.X, 1),
                        ["y"] = Math.Round(spot.Pos.Y, 1),
                        ["z"] = Math.Round(spot.Pos.Z, 1),
                        ["moved"] = Math.Round(Flat(spot.Pos, r.p), 1),
                        ["how"] = how,
                    };
                    if (rowFallback)
                        row["fallback"] = true;
                    rowsOut[r.id.ToString()] = row;
                }
            }

            var output = new JsonObject
            {
                ["meshes"] = meshes,
                ["rows"] = rowsOut,
                ["unplaced"] = unplaced,
                ["noArrivals"] = new JsonArray(noArrivals.Select(z => (JsonNode)z).ToArray()),
            };
            File.WriteAllText(args[1], output.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            Console.WriteLine($"navplace: {rowsOut.Count} rows placed, {unplaced.Count} unplaced, {zones.Count(z => z.Value != null)} zones");
            return 0;
        }

        private static Zone LoadZone(Dictionary<string, Zone> zones, NavManifest manifest, string name, string arrivalDir)
        {
            if (zones.TryGetValue(name, out var z))
                return z;
            string file = manifest.ResolveFile(name);
            if (file == null || !File.Exists(file))
                return zones[name] = null;
            var world = NavWorld.Load(file);
            z = new Zone
            {
                World = world, Instance = world.CreateInstance("navplace"), File = file, IslandPolys = new Dictionary<int, int>(),
                Arrivals = new List<Vector3>(), ReachedCache = new Dictionary<long, bool>(),
            };
            for (int gate = 0; gate < world.Gates.Count; gate++)
                z.Instance.SetGate(gate, true);
            for (int t = 0; t < world.Mesh.GetMaxTiles(); t++)
            {
                var tile = world.Mesh.GetTile(t);
                if (tile?.data?.header == null)
                    continue;
                long baseRef = world.Mesh.GetPolyRefBase(tile);
                for (int i = 0; i < tile.data.header.polyCount; i++)
                {
                    long poly = baseRef | (uint)i;
                    if ((world.PolyFlags(poly) & (int)NavFlags.Pruned) != 0)
                        continue;
                    int island = world.IslandOf(poly);
                    z.IslandPolys[island] = z.IslandPolys.TryGetValue(island, out int n) ? n + 1 : 1;
                }
            }
            if (arrivalDir != null)
                LoadArrivals(z, Path.Combine(arrivalDir, name + ".json"));
            return zones[name] = z;
        }

        /// <summary>
        /// Arrival points (spawn kinds aetheryte, entrance, border) snapped like navgen validate does: a
        /// known height must snap within 1.5 m; a border (height unknown, y 0) takes the column's floor on
        /// the island with the most area.
        /// </summary>
        private static void LoadArrivals(Zone z, string path)
        {
            if (!File.Exists(path))
                return;
            List<float> islandArea = null;
            foreach (var s in JsonNode.Parse(File.ReadAllText(path))["spawns"].AsArray())
            {
                string kind = (string)s["kind"];
                if (kind != "aetheryte" && kind != "entrance" && kind != "border")
                    continue;
                var p = s["pos"].AsArray();
                var pos = new Vector3((float)p[0], (float)p[1], (float)p[2]);
                if (pos.Y == 0.0f)
                {
                    islandArea ??= IslandAreas(z.World);
                    if (ColumnFloor(z.World, pos.X, pos.Z, islandArea, out var floor))
                        z.Arrivals.Add(floor);
                    continue;
                }
                var sn = z.Instance.Snap(pos, NavAgent.Player);
                if (sn.Ok && Flat(sn.Position, pos) <= 2.0f && MathF.Abs(sn.Position.Y - pos.Y) <= 1.5f)
                    z.Arrivals.Add(sn.Position);
            }
        }

        private sealed class PlayerFilter : IDtQueryFilter
        {
            public bool PassFilter(long refs, DtMeshTile tile, DtPoly poly) =>
                NavAgent.Player.Passes(poly.flags) && (poly.flags & (int)NavFlags.Pruned) == 0;

            public float GetCost(RcVec3f pa, RcVec3f pb, long prevRef, DtMeshTile prevTile, DtPoly prevPoly,
                long curRef, DtMeshTile curTile, DtPoly curPoly, long nextRef, DtMeshTile nextTile, DtPoly nextPoly) => RcVec3f.Distance(pa, pb);
        }

        private static bool ColumnFloor(NavWorld w, float x, float z, List<float> islandArea, out Vector3 floor)
        {
            floor = default;
            var query = new DtNavMeshQuery(w.Mesh);
            var polys = new long[256];
            if (query.QueryPolygons(new RcVec3f(x, 0, z), new RcVec3f(0.05f, 2000.0f, 0.05f), new PlayerFilter(), polys, out int n, polys.Length).Failed())
                return false;
            float bestArea = -1;
            for (int i = 0; i < n; i++)
            {
                if (w.Mesh.GetTileAndPolyByRef(polys[i], out var tile, out var poly).Failed() || poly.GetPolyType() != DtPolyTypes.DT_POLYTYPE_GROUND)
                    continue;
                if (!w.Mesh.GetPolyHeight(tile, poly, new RcVec3f(x, 0, z), out float h))
                    continue;
                int island = w.IslandOf(polys[i]);
                float area = island >= 0 && island < islandArea.Count ? islandArea[island] : 0;
                if (area > bestArea)
                {
                    bestArea = area;
                    floor = new Vector3(x, h, z);
                }
            }
            return bestArea >= 0;
        }

        private static List<float> IslandAreas(NavWorld w)
        {
            var area = new List<float>();
            for (int t = 0; t < w.Mesh.GetMaxTiles(); t++)
            {
                var tile = w.Mesh.GetTile(t);
                if (tile?.data?.header == null)
                    continue;
                long baseRef = w.Mesh.GetPolyRefBase(tile);
                var v = tile.data.verts;
                for (int i = 0; i < tile.data.header.polyCount; i++)
                {
                    var poly = tile.data.polys[i];
                    int island = w.IslandOf(baseRef | (uint)i);
                    if (island < 0 || poly.GetPolyType() != DtPolyTypes.DT_POLYTYPE_GROUND)
                        continue;
                    float a = 0;
                    for (int k = 0; k < poly.vertCount; k++)
                    {
                        int p0 = poly.verts[k] * 3, p1 = poly.verts[(k + 1) % poly.vertCount] * 3;
                        a += v[p0] * v[p1 + 2] - v[p1] * v[p0 + 2];
                    }
                    while (area.Count <= island)
                        area.Add(0);
                    area[island] += MathF.Abs(a) * 0.5f;
                }
            }
            return area;
        }

        /// <summary>Can a player walk to this ground from one of the zone's arrival points (gates open)?</summary>
        private static bool ReachedFromArrival(Zone z, long poly, Vector3 pos)
        {
            if (z.Arrivals.Count == 0)
                return true;
            int node = z.World.NodeOf(poly);
            long key = node >= 0 ? node : (1L << 40) | poly;
            if (z.ReachedCache.TryGetValue(key, out bool hit))
                return hit;
            hit = z.Arrivals.Any(a => z.Instance.Reachable(a, pos, NavAgent.Player).Reachable);
            z.ReachedCache[key] = hit;
            return hit;
        }

        private static Ground Snap(Zone z, Vector3 p)
        {
            var s = z.Instance.Snap(new Vector3(p.X, p.Y, p.Z), NavAgent.Mob);
            if (!s.Ok || z.World.PolyArea(s.Poly) == NavArea.WATER)
                return default;
            return new Ground { Pos = s.Position, Island = z.World.IslandOf(s.Poly), Ok = true, Reached = ReachedFromArrival(z, s.Poly, s.Position) };
        }

        private static bool Reachable(Zone z, Vector3 a, Vector3 b) => z.Instance.Reachable(a, b, NavAgent.Mob).Reachable;

        /// <summary>The ground of a group's trusted and kept rows that a player can reach: the one on the biggest island.</summary>
        private static Ground IslandOfPlaced(Zone z, List<Vector3> placed)
        {
            Ground best = default;
            foreach (var p in placed)
            {
                var g = Snap(z, p);
                if (g.Ok && g.Reached && (!best.Ok || Size(z, g.Island) > Size(z, best.Island)))
                    best = g;
            }
            return best;
        }

        /// <summary>Rings of samples out to radius on ground reached from arrival points; the largest island seen, at its sample nearest the anchor.</summary>
        private static Ground BestNear(Zone z, Vector3 anchor, float radius)
        {
            var found = new List<Ground>();
            foreach (float r in Radii)
            {
                if (r > radius)
                    break;
                int steps = r == 0 ? 1 : r < 16 ? 8 : 16;
                for (int k = 0; k < steps; k++)
                {
                    double a = 2 * Math.PI * k / steps;
                    var g = Snap(z, new Vector3(anchor.X + r * (float)Math.Cos(a), anchor.Y, anchor.Z + r * (float)Math.Sin(a)));
                    if (g.Ok && g.Reached && Flat(g.Pos, anchor) <= radius)
                        found.Add(g);
                }
            }
            if (found.Count == 0)
                return default;
            // islands at least half the size of the largest one seen count as large: the nearest of them wins
            int largest = found.Max(g => Size(z, g.Island));
            return found.Where(g => Size(z, g.Island) * 2 >= largest).OrderBy(g => Flat(g.Pos, anchor)).ThenBy(g => g.Island).First();
        }

        private static JsonObject Unplaced(Zone z, long id, Vector3 p, string zoneName, string reason)
        {
            var o = new JsonObject { ["id"] = id, ["zone"] = zoneName, ["reason"] = reason };
            var n = Nearest(z, p);
            if (n.Ok)
                o["nearest"] = Math.Round(Flat(n.Pos, p), 1);
            return o;
        }

        /// <summary>
        /// The dry mob ground a player can reach from an arrival point that is nearest p in XZ, at any
        /// distance: every poly's closest point to p, tried nearest first until one snaps back reached.
        /// </summary>
        private static Ground Nearest(Zone z, Vector3 p)
        {
            var w = z.World;
            var cands = new List<(float d, long poly, Vector3 pos)>();
            for (int t = 0; t < w.Mesh.GetMaxTiles(); t++)
            {
                var tile = w.Mesh.GetTile(t);
                if (tile?.data?.header == null)
                    continue;
                long baseRef = w.Mesh.GetPolyRefBase(tile);
                var v = tile.data.verts;
                for (int i = 0; i < tile.data.header.polyCount; i++)
                {
                    var poly = tile.data.polys[i];
                    long pref = baseRef | (uint)i;
                    if (poly.GetPolyType() != DtPolyTypes.DT_POLYTYPE_GROUND || !NavAgent.Mob.Passes(poly.flags)
                        || (poly.flags & (int)NavFlags.Pruned) != 0 || w.PolyArea(pref) == NavArea.WATER)
                        continue;
                    var pos = ClosestOnPoly(v, poly, p);
                    cands.Add((Flat(pos, p), pref, pos));
                }
            }
            foreach (var c in cands.OrderBy(c => c.d).ThenBy(c => c.poly))
            {
                var g = Snap(z, c.pos);
                if (g.Ok && g.Reached && Flat(g.Pos, c.pos) <= MEMBER_SLACK && MathF.Abs(g.Pos.Y - c.pos.Y) <= 2.0f)
                    return g;
            }
            return default;
        }

        /// <summary>The point of a poly nearest p in XZ, a little inside its edge, at the poly's height there.</summary>
        private static Vector3 ClosestOnPoly(float[] v, DtPoly poly, Vector3 p)
        {
            int n = poly.vertCount;
            var c = Vector3.Zero;
            for (int k = 0; k < n; k++)
                c += new Vector3(v[poly.verts[k] * 3], v[poly.verts[k] * 3 + 1], v[poly.verts[k] * 3 + 2]);
            c /= n;
            Vector3 best = c;
            float bestD = float.MaxValue;
            bool inside = false;
            for (int k = 0; k < n; k++)
            {
                int i0 = poly.verts[k] * 3, i1 = poly.verts[(k + 1) % n] * 3;
                var a = new Vector3(v[i0], v[i0 + 1], v[i0 + 2]);
                var b = new Vector3(v[i1], v[i1 + 1], v[i1 + 2]);
                float ex = b.X - a.X, ez = b.Z - a.Z;
                if ((a.Z > p.Z) != (b.Z > p.Z) && p.X < a.X + (p.Z - a.Z) * ex / ez)
                    inside = !inside;
                float len2 = ex * ex + ez * ez;
                float u = len2 > 0 ? Math.Clamp(((p.X - a.X) * ex + (p.Z - a.Z) * ez) / len2, 0, 1) : 0;
                var q = Vector3.Lerp(a, b, u);
                float d = (q.X - p.X) * (q.X - p.X) + (q.Z - p.Z) * (q.Z - p.Z);
                if (d < bestD)
                {
                    bestD = d;
                    best = q;
                }
            }
            if (inside)
            {
                // over the poly: its height under p, from the triangle fan around the centre
                for (int k = 0; k < n; k++)
                {
                    int i0 = poly.verts[k] * 3, i1 = poly.verts[(k + 1) % n] * 3;
                    if (TriHeight(c, new Vector3(v[i0], v[i0 + 1], v[i0 + 2]), new Vector3(v[i1], v[i1 + 1], v[i1 + 2]), p, out float h))
                        return new Vector3(p.X, h, p.Z);
                }
                return new Vector3(p.X, c.Y, p.Z);
            }
            // pulled a little towards the centre so the point is on this poly, not its neighbour
            var dir = new Vector2(c.X - best.X, c.Z - best.Z);
            float len = dir.Length();
            float step = MathF.Min(0.1f, len * 0.5f);
            return len > 0 ? Vector3.Lerp(best, c, step / len) : best;
        }

        private static bool TriHeight(Vector3 a, Vector3 b, Vector3 c, Vector3 p, out float h)
        {
            h = 0;
            float d = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z);
            if (MathF.Abs(d) < 1e-6f)
                return false;
            float l1 = ((b.Z - c.Z) * (p.X - c.X) + (c.X - b.X) * (p.Z - c.Z)) / d;
            float l2 = ((c.Z - a.Z) * (p.X - c.X) + (a.X - c.X) * (p.Z - c.Z)) / d;
            float l3 = 1 - l1 - l2;
            const float EPS = -1e-4f;
            if (l1 < EPS || l2 < EPS || l3 < EPS)
                return false;
            h = l1 * a.Y + l2 * b.Y + l3 * c.Y;
            return true;
        }

        private static int Size(Zone z, int island) => z.IslandPolys.TryGetValue(island, out int n) ? n : 0;

        private static float Flat(Vector3 a, Vector3 b) => MathF.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Z - b.Z) * (a.Z - b.Z));
    }
}
