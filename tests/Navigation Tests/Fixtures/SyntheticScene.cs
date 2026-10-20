using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using DotRecast.Core.Numerics;
using DotRecast.Detour;
using DotRecast.Recast;
using DotRecast.Recast.Geom;

namespace Meteor.Navigation.Tests.Fixtures
{
    /// <summary>
    /// A small world built with DotRecast.Recast and written as .nav, standing in for navgen's fixture:
    ///
    ///   room A ─door g1 (GATE_0)─ room B ─ long hall ─────────────── room E ─player-only strip─ pocket F
    ///     └── loop corridor (wall g2, GATE_1) ──┘        │ lift pad ⇅ lift l0 (gate g3) ⇅ platform (y 10)
    ///                                                    │ drop pad ← drop l1 (one-way) ←──┘
    ///   water pool in room B; a rooftop slab (y 6) in room A that no seed reaches (pruned).
    ///
    /// Tiles and graph cells are 32 m; areas, flags, gates, pruning, islands and the component graph
    /// follow FORMATS §3–§4 (graph nodes: SCCs per cell keyed by gate, flag class and off-mesh link).
    /// </summary>
    sealed class SyntheticScene
    {
        public const float CS = 0.25f, CH = 0.2f, RADIUS = 0.5f, HEIGHT = 2.0f, CLIMB = 0.75f, TILE = 32.0f;
        public const int GATE_DOOR = 0, GATE_WALL = 1, GATE_LIFT = 2;
        public const int LINK_LIFT = 0, LINK_DROP = 1;

        // named points
        public static readonly Vector3 A = new Vector3(5, 0, 5), A2 = new Vector3(25, 0, 8), ACenter = new Vector3(15, 0, 15);
        public static readonly Vector3 B = new Vector3(55, 0, 5), E = new Vector3(175, 0, 20), F = new Vector3(199, 0, 5);
        public static readonly Vector3 Pad = new Vector3(105, 0, 21), Top = new Vector3(105, 10, 35), DropPad = new Vector3(116, 0, 35);
        public static readonly Vector3 Roof = new Vector3(13, 6, 13), Pool = new Vector3(45, 0, 15);
        public static readonly Vector3 LiftBottom = new Vector3(105, 0, 23.5f), LiftTop = new Vector3(105, 10, 31.5f);
        public static readonly Vector3 DropTop = new Vector3(109, 10, 35), DropBottom = new Vector3(113.5f, 0, 35);
        // a deck 4 m over open ground, not joined to it or the rest (its own seeds): a floor over a floor
        public static readonly Vector3 UnderDeck = new Vector3(225, 0, 10), OnDeck = new Vector3(225, 4, 10);

        // XZ rectangles at a height: (x0, z0, x1, z1, y)
        private static readonly (float x0, float z0, float x1, float z1, float y)[] Floors =
        {
            (0, 0, 30, 30, 0),          // room A
            (30, 13, 34, 17, 0),        // door strip
            (34, 0, 64, 30, 0),         // room B
            (0, 30, 6, 60, 0),          // loop: west leg
            (0, 54, 64, 60, 0),         // loop: north band
            (58, 30, 64, 54, 0),        // loop: east leg
            (64, 13, 160, 17, 0),       // hall
            (160, 0, 190, 30, 0),       // room E
            (190, 3, 194, 7, 0),        // player-only strip
            (194, 0, 204, 10, 0),       // pocket F
            (100, 17, 110, 25, 0),      // lift pad
            (100, 30, 110, 40, 10),     // platform
            (112, 17, 120, 30, 0),      // drop pad strip
            (112, 30, 120, 40, 0),      // drop pad
            (10, 10, 16, 16, 6),        // rooftop slab
            (220, 0, 240, 20, 0),       // ground under the deck
            (220, 0, 240, 20, 4),       // deck
        };

        public static readonly (float x0, float z0, float x1, float z1) DoorRect = (30, 12, 34, 18), WallRect = (30, 53, 34, 61),
            PoolRect = (40, 5, 50, 25), PlayerOnlyRect = (190, 2, 194, 8);

        public DtNavMesh Mesh;
        public NavFileWriter Writer;
        public int PrunedPolys;

        private static readonly Lazy<string> cached = new Lazy<string>(() =>
        {
            string dir = Path.Combine(Path.GetTempPath(), "meteor-nav-tests");
            Directory.CreateDirectory(dir);
            string path = Path.Combine(dir, $"synthetic-{Environment.ProcessId}.nav");
            Build().Writer.Write(path);
            return path;
        });

        /// <summary>The scene written once per test run.</summary>
        public static string FilePath => cached.Value;

        public static NavWorld LoadWorld() => NavWorld.Load(FilePath);

        public static SyntheticScene Build()
        {
            var verts = new List<float>();
            var faces = new List<int>();
            foreach (var (x0, z0, x1, z1, y) in Floors)
            {
                int b = verts.Count / 3;
                verts.AddRange(new[] { x0, y, z0, x1, y, z0, x1, y, z1, x0, y, z1 });
                // counter-clockwise seen from above
                faces.AddRange(new[] { b, b + 2, b + 1, b, b + 3, b + 2 });
            }
            var geom = new RcSampleInputGeomProvider(verts.ToArray(), faces.ToArray());
            AddVolume(geom, DoorRect, NavArea.GATE_0);
            AddVolume(geom, WallRect, NavArea.GATE_0 + 1);
            AddVolume(geom, PoolRect, NavArea.WATER);
            AddVolume(geom, PlayerOnlyRect, NavArea.PLAYER_ONLY);

            int tileVoxels = (int)(TILE / CS);
            var cfg = new RcConfig(true, tileVoxels, tileVoxels, RcConfig.CalcBorder(RADIUS, CS), RcPartition.WATERSHED,
                CS, CH, 45.0f, HEIGHT, RADIUS, CLIMB, 1, 5, 12.0f, 1.3f, 6, 6.0f, 1.0f,
                true, true, true, new RcAreaModification(NavArea.GROUND), true);
            var results = new RcBuilder().BuildTiles(geom, cfg, false, true, 1);

            var bmin = geom.GetMeshBoundsMin();
            var meshParams = new DtNavMeshParams
            {
                orig = bmin,
                tileWidth = TILE,
                tileHeight = TILE,
                maxTiles = 64,
                maxPolys = 1 << 14,
            };

            var links = new List<NavLinkDef>
            {
                new NavLinkDef { Index = LINK_LIFT, Id = "l0", Kind = "LIFT", Gate = GATE_LIFT, A = LiftBottom, B = LiftTop, Bidir = true },
                new NavLinkDef { Index = LINK_DROP, Id = "l1", Kind = "DROP", Gate = -1, A = DropTop, B = DropBottom, Bidir = false },
            };

            var mesh = new DtNavMesh();
            mesh.Init(in meshParams, 6);
            var tiles = new List<(long, DtMeshData)>();
            foreach (var r in results.OrderBy(r => r.TileZ).ThenBy(r => r.TileX))
            {
                var pm = r.Mesh;
                if (pm == null || pm.npolys == 0)
                    continue;
                for (int i = 0; i < pm.npolys; i++)
                    pm.flags[i] = FlagsForArea(pm.areas[i]);
                var dm = r.MeshDetail;
                var p = new DtNavMeshCreateParams
                {
                    verts = pm.verts, vertCount = pm.nverts, polys = pm.polys, polyAreas = pm.areas, polyFlags = pm.flags,
                    polyCount = pm.npolys, nvp = pm.nvp,
                    detailMeshes = dm.meshes, detailVerts = dm.verts, detailVertsCount = dm.nverts, detailTris = dm.tris, detailTriCount = dm.ntris,
                    walkableHeight = HEIGHT, walkableRadius = RADIUS, walkableClimb = CLIMB,
                    bmin = pm.bmin, bmax = pm.bmax, cs = CS, ch = CH, buildBvTree = true,
                    tileX = r.TileX, tileZ = r.TileZ, tileLayer = 0,
                };
                AddLinks(p, links);
                var data = DtNavMeshBuilder.CreateNavMeshData(p);
                if (data == null)
                    continue;
                if (mesh.AddTile(data, 0, 0, out long tileRef).Failed())
                    throw new InvalidOperationException("tile add failed");
                tiles.Add((tileRef, data));
            }

            var scene = new SyntheticScene { Mesh = mesh };
            var all = AllPolys(mesh, tiles);

            // gates
            var gates = new List<NavGateDef>
            {
                new NavGateDef { Index = GATE_DOOR, Id = "g1", Kind = "DOOR", Default = "open" },
                new NavGateDef { Index = GATE_WALL, Id = "g2", Kind = "WALL", Default = "open" },
                new NavGateDef { Index = GATE_LIFT, Id = "g3", Kind = "LIFT", Default = "open", Links = new[] { LINK_LIFT } },
            };
            gates[GATE_DOOR].Driver["mapobj"] = "sgrp_test_door";
            gates[GATE_WALL].Driver["timeline"] = "time_test_show,time_test_hide";
            gates[GATE_LIFT].Driver["mapobj"] = "sgrp_test_elv1";
            gates[GATE_DOOR].Polys = all.Where(r => Area(mesh, r) == NavArea.GATE_0).ToArray();
            gates[GATE_WALL].Polys = all.Where(r => Area(mesh, r) == NavArea.GATE_0 + 1).ToArray();
            var gateOf = new Dictionary<long, int>();
            foreach (var g in gates)
                foreach (long r in g.Polys)
                    gateOf[r] = g.Index;
            foreach (long r in all)
                if (Con(mesh, r) is DtOffMeshConnection con && links[con.userId].Gate >= 0)
                    gateOf[r] = links[con.userId].Gate;
            gates[GATE_LIFT].Polys = gateOf.Where(kv => kv.Value == GATE_LIFT).Select(kv => kv.Key).ToArray();

            // prune: flood from the seed over links with every gate open
            var seeds = new List<NavSeedDef>
            {
                new NavSeedDef { Id = "s1", Pos = A, Label = "aetheryte" },
                new NavSeedDef { Id = "s2", Pos = UnderDeck, Label = "under deck" },
                new NavSeedDef { Id = "s3", Pos = OnDeck, Label = "deck" },
            };
            var q = new DtNavMeshQuery(mesh);
            var reached = new HashSet<long>();
            var stack = new Stack<long>();
            foreach (var s in seeds)
            {
                q.FindNearestPoly(new RcVec3f(s.Pos.X, s.Pos.Y, s.Pos.Z), new RcVec3f(2, 4, 2), new DtQueryDefaultFilter(), out long sr, out _, out _);
                if (sr != 0 && reached.Add(sr))
                    stack.Push(sr);
            }
            while (stack.Count > 0)
                foreach (long n in Neighbours(mesh, stack.Pop()))
                    if (reached.Add(n))
                        stack.Push(n);
            foreach (long r in all)
                if (!reached.Contains(r))
                {
                    mesh.GetTileAndPolyByRefUnsafe(r, out _, out var poly);
                    poly.flags |= (int)NavFlags.Pruned;
                    scene.PrunedPolys++;
                }

            var islands = Islands(mesh, all);
            var graph = BuildGraph(mesh, all, gateOf, islands, bmin);

            scene.Writer = new NavFileWriter
            {
                Params = meshParams,
                CellSize = CS, CellHeight = CH, WalkableHeight = HEIGHT, WalkableClimb = CLIMB, WalkableRadius = RADIUS,
                Islands = all.Select(r => (uint)islands[r]).ToArray(),
                Graph = graph,
            };
            scene.Writer.Tiles.AddRange(tiles);
            scene.Writer.Areas.AddRange(new[]
            {
                new NavAreaDef { Id = NavArea.GROUND, Name = "GROUND", Flags = 1, Cost = 1 },
                new NavAreaDef { Id = NavArea.WATER, Name = "WATER", Flags = 3, Cost = 2 },
                new NavAreaDef { Id = NavArea.PLAYER_ONLY, Name = "PLAYER_ONLY", Flags = 5, Cost = 1 },
                new NavAreaDef { Id = NavArea.GATE_0, Name = "GATE_0", Flags = 9, Cost = 1 },
                new NavAreaDef { Id = NavArea.GATE_0 + 1, Name = "GATE_1", Flags = 9, Cost = 1 },
                new NavAreaDef { Id = NavArea.LIFT, Name = "LIFT", Flags = 0x10, Cost = 1 },
                new NavAreaDef { Id = NavArea.DROP, Name = "DROP", Flags = 0x20, Cost = 1 },
            });
            scene.Writer.Gates.AddRange(gates);
            scene.Writer.Links.AddRange(links);
            scene.Writer.Seeds.AddRange(seeds);
            scene.Writer.Extra.Add(("XTRA", new byte[] { 1, 2, 3 }));
            return scene;
        }

        private static void AddVolume(RcSampleInputGeomProvider geom, (float x0, float z0, float x1, float z1) r, int area)
        {
            geom.AddConvexVolume(new RcConvexVolume
            {
                verts = new[] { r.x0, 0, r.z0, r.x1, 0, r.z0, r.x1, 0, r.z1, r.x0, 0, r.z1 },
                hmin = -1.0f,
                hmax = 2.0f,
                areaMod = new RcAreaModification(area),
            });
        }

        private static int FlagsForArea(int area)
        {
            switch (area)
            {
                case NavArea.GROUND: return (int)NavFlags.Walk;
                case NavArea.WATER: return (int)(NavFlags.Walk | NavFlags.Water);
                case NavArea.PLAYER_ONLY: return (int)(NavFlags.Walk | NavFlags.PlayerOnly);
                case NavArea.LIFT: return (int)NavFlags.Lift;
                case NavArea.DROP: return (int)NavFlags.Drop;
                case NavArea.LINK: return (int)(NavFlags.Walk | NavFlags.Link);
                default: return area >= NavArea.GATE_0 && area <= NavArea.GATE_3 ? (int)(NavFlags.Walk | NavFlags.Gate) : 0;
            }
        }

        private static void AddLinks(DtNavMeshCreateParams p, List<NavLinkDef> links)
        {
            p.offMeshConCount = links.Count;
            p.offMeshConVerts = new float[links.Count * 6];
            p.offMeshConRad = new float[links.Count];
            p.offMeshConFlags = new int[links.Count];
            p.offMeshConAreas = new int[links.Count];
            p.offMeshConDir = new int[links.Count];
            p.offMeshConUserID = new int[links.Count];
            for (int i = 0; i < links.Count; i++)
            {
                var l = links[i];
                new[] { l.A.X, l.A.Y, l.A.Z, l.B.X, l.B.Y, l.B.Z }.CopyTo(p.offMeshConVerts, i * 6);
                p.offMeshConRad[i] = 1.0f;
                bool lift = l.Kind == "LIFT";
                p.offMeshConAreas[i] = lift ? NavArea.LIFT : NavArea.DROP;
                p.offMeshConFlags[i] = FlagsForArea(p.offMeshConAreas[i]);
                p.offMeshConDir[i] = l.Bidir ? DtDetour.DT_OFFMESH_CON_BIDIR : 0;
                p.offMeshConUserID[i] = l.Index;
            }
        }

        /// <summary>Every poly in TILE order, poly index order.</summary>
        private static List<long> AllPolys(DtNavMesh mesh, List<(long tileRef, DtMeshData data)> tiles)
        {
            var list = new List<long>();
            foreach (var (tileRef, data) in tiles)
            {
                var tile = mesh.GetTileByRef(tileRef);
                long b = mesh.GetPolyRefBase(tile);
                for (int i = 0; i < data.header.polyCount; i++)
                    list.Add(b | (uint)i);
            }
            return list;
        }

        private static int Area(DtNavMesh mesh, long r)
        {
            mesh.GetTileAndPolyByRefUnsafe(r, out _, out var p);
            return p.GetArea();
        }

        private static DtOffMeshConnection Con(DtNavMesh mesh, long r)
        {
            mesh.GetTileAndPolyByRefUnsafe(r, out var t, out var p);
            if (p.GetPolyType() != DtPolyTypes.DT_POLYTYPE_OFFMESH_CONNECTION)
                return null;
            return t.data.offMeshCons[p.index - t.data.header.offMeshBase];
        }

        private static IEnumerable<long> Neighbours(DtNavMesh mesh, long r)
        {
            mesh.GetTileAndPolyByRefUnsafe(r, out var t, out var p);
            for (int k = p.firstLink; k != DtDetour.DT_NULL_LINK; k = t.links[k].next)
                if (t.links[k].refs != 0)
                    yield return t.links[k].refs;
        }

        private static int Flags(DtNavMesh mesh, long r)
        {
            mesh.GetTileAndPolyByRefUnsafe(r, out _, out var p);
            return p.flags;
        }

        private static Dictionary<long, int> Islands(DtNavMesh mesh, List<long> all)
        {
            var adj = all.ToDictionary(r => r, r => new List<long>());
            foreach (long r in all)
                foreach (long n in Neighbours(mesh, r))
                    if (adj.ContainsKey(n))
                    {
                        adj[r].Add(n);
                        adj[n].Add(r);
                    }
            var id = new Dictionary<long, int>();
            int next = 0;
            foreach (long start in all)
            {
                if (id.ContainsKey(start))
                    continue;
                var stack = new Stack<long>();
                id[start] = next;
                stack.Push(start);
                while (stack.Count > 0)
                    foreach (long n in adj[stack.Pop()])
                        if (!id.ContainsKey(n))
                        {
                            id[n] = next;
                            stack.Push(n);
                        }
                next++;
            }
            return id;
        }

        private static NavGraphData BuildGraph(DtNavMesh mesh, List<long> all, Dictionary<long, int> gateOf, Dictionary<long, int> islands, RcVec3f orig)
        {
            var live = all.Where(r => (Flags(mesh, r) & (int)NavFlags.Pruned) == 0).ToList();
            var key = new Dictionary<long, (int cx, int cz, int gate, int flags, long link)>();
            foreach (long r in live)
            {
                var c = mesh.GetPolyCenter(r);
                bool link = Con(mesh, r) != null;
                key[r] = ((int)MathF.Floor((c.X - orig.X) / TILE), (int)MathF.Floor((c.Z - orig.Z) / TILE),
                    gateOf.TryGetValue(r, out int g) ? g : -1, Flags(mesh, r), link ? r : 0);
            }

            // Tarjan SCC over links that stay within a key
            var index = new Dictionary<long, int>();
            var low = new Dictionary<long, int>();
            var onStack = new HashSet<long>();
            var st = new Stack<long>();
            var comp = new Dictionary<long, int>();
            int counter = 0, comps = 0;
            void Visit(long v)
            {
                index[v] = low[v] = counter++;
                st.Push(v);
                onStack.Add(v);
                foreach (long w in Neighbours(mesh, v))
                {
                    if (!key.ContainsKey(w) || !key[w].Equals(key[v]))
                        continue;
                    if (!index.ContainsKey(w))
                    {
                        Visit(w);
                        low[v] = Math.Min(low[v], low[w]);
                    }
                    else if (onStack.Contains(w))
                        low[v] = Math.Min(low[v], index[w]);
                }
                if (low[v] == index[v])
                {
                    long w;
                    do
                    {
                        w = st.Pop();
                        onStack.Remove(w);
                        comp[w] = comps;
                    } while (w != v);
                    comps++;
                }
            }
            foreach (long r in live)
                if (!index.ContainsKey(r))
                    Visit(r);

            var byComp = live.GroupBy(r => comp[r]).ToDictionary(g => g.Key, g => g.ToList());
            var nodes = new NavGraphNode[comps];
            for (int n = 0; n < comps; n++)
            {
                var members = byComp[n];
                var sum = members.Select(r => mesh.GetPolyCenter(r)).Aggregate(RcVec3f.Zero, (a, b) => RcVec3f.Add(a, b));
                var avg = new RcVec3f(sum.X / members.Count, sum.Y / members.Count, sum.Z / members.Count);
                long best = members.OrderBy(r => RcVec3f.DistanceSquared(mesh.GetPolyCenter(r), avg)).First();
                RcVec3f center = mesh.GetPolyCenter(best);
                if (Con(mesh, best) == null)
                    mesh.ClosestPointOnPoly(best, avg, out center, out _);
                var k = key[best];
                nodes[n] = new NavGraphNode
                {
                    CellX = k.cx, CellZ = k.cz, Center = new Vector3(center.X, center.Y, center.Z), CenterPoly = best,
                    Gate = k.gate, Island = islands[best], Flags = k.flags,
                };
            }

            var edges = new Dictionary<(int, int), NavGraphEdge>();
            foreach (long r in live)
                foreach (long w in Neighbours(mesh, r))
                {
                    if (!comp.TryGetValue(w, out int to) || comp[r] == to)
                        continue;
                    int from = comp[r];
                    if (edges.ContainsKey((from, to)))
                        continue;
                    edges[(from, to)] = new NavGraphEdge
                    {
                        From = from, To = to,
                        Cost = Vector3.Distance(nodes[from].Center, nodes[to].Center),
                        Gate = nodes[to].Gate >= 0 ? nodes[to].Gate : nodes[from].Gate,
                        Flags = nodes[from].Flags | nodes[to].Flags,
                    };
                }

            return new NavGraphData
            {
                CellSize = TILE,
                Nodes = nodes,
                Edges = edges.Values.OrderBy(e => e.From).ThenBy(e => e.To).ToArray(),
                PolyNode = all.Select(r => comp.TryGetValue(r, out int n) ? n : -1).ToArray(),
            };
        }

        public static bool InRect(Vector3 p, (float x0, float z0, float x1, float z1) r) =>
            p.X >= r.x0 && p.X <= r.x1 && p.Z >= r.z0 && p.Z <= r.z1;
    }
}
