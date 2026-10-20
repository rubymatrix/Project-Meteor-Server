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
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Threading;
using DotRecast.Core;
using DotRecast.Core.Numerics;
using DotRecast.Detour;
using DotRecast.Detour.Io;

namespace Meteor.Navigation
{
    /// <summary>Per-thread scratch for queries; rented from the world's pool.</summary>
    internal sealed class NavQueryContext
    {
        public const int MAX_POLYS = 4096;
        public const int MAX_RAY_POLYS = 512;
        public const int MAX_CORNERS = 256;

        private static long seedCounter;

        public readonly DtNavMeshQuery Query;
        public readonly long[] Polys = new long[MAX_POLYS];
        public readonly long[] RayPolys = new long[MAX_RAY_POLYS];
        public readonly DtStraightPath[] Corners = new DtStraightPath[MAX_CORNERS];
        public readonly RcRand Rand;
        public readonly NavFilter Filter = new NavFilter();
        public readonly NavFilter Other = new NavFilter();

        // A* over the component graph
        public readonly float[] G;
        public readonly int[] Parent;
        public readonly int[] Stamp;
        public int StampValue;
        public readonly PriorityQueue<int, float> Open = new PriorityQueue<int, float>();

        public NavQueryContext(DtNavMesh mesh, int nodeCount)
        {
            Query = new DtNavMeshQuery(mesh);
            Rand = new RcRand(Interlocked.Increment(ref seedCounter) * 2654435761L + Environment.TickCount64);
            G = new float[nodeCount];
            Parent = new int[nodeCount];
            Stamp = new int[nodeCount];
        }
    }

    /// <summary>
    /// One loaded .nav: the Detour mesh, area/gate/link tables, the component graph and a query
    /// context pool. Immutable after load and shared by every NavInstance (area) using the file.
    /// Gate state lives on the instance; every query here takes it explicitly.
    /// </summary>
    public sealed class NavWorld
    {
        public const float WIDE_VERTICAL = 64.0f;
        private const float EDGE_BACKOFF = 0.1f;
        private static readonly float[] SightLookAhead = { 0.75f, 2.0f, 4.0f, 8.0f };

        public readonly string Name;
        public readonly string FilePath;
        public readonly NavMeta Meta;
        public readonly DtNavMesh Mesh;
        public readonly IReadOnlyList<NavAreaDef> Areas;
        public readonly IReadOnlyList<NavGateDef> Gates;
        public readonly IReadOnlyList<NavLinkDef> Links;
        public readonly IReadOnlyList<NavSeedDef> Seeds;
        public readonly NavGraphData Graph;
        public readonly int TileCount;
        public readonly int PolyCount;
        public readonly string ValidationJson;
        /// <summary>Things wrong with the file that didn't stop it loading (e.g. a graph that doesn't match the tiles).</summary>
        public readonly IReadOnlyList<string> Warnings;
        public readonly NavStats Stats = new NavStats();

        /// <summary>Agent radius the mesh was eroded by; agents wider than this get their corners pushed out.</summary>
        public float BakedRadius => Meta.WalkableRadius;

        internal readonly float[] DefaultCosts = new float[NavArea.MAX];
        private readonly int[][] gateOfPoly;      // [tile index][poly index] → gate, -1 none
        private readonly int[][] nodeOfPoly;      // [tile index][poly index] → graph node, -1 none
        private readonly int[][] islandOfPoly;    // [tile index][poly index] → ISLD island
        private readonly int[] edgeStart;         // CSR over Graph.Edges sorted by From
        private readonly float[] linkNodeRise;    // graph node of a link → height between the cells at its ends
        private readonly NavGraphEdge[] edges;
        private readonly Dictionary<string, int> gateIndex = new Dictionary<string, int>(StringComparer.Ordinal);
        private readonly Dictionary<int, List<long>> linkPolys = new Dictionary<int, List<long>>();
        private readonly Dictionary<long, float> linkRise = new Dictionary<long, float>();   // off-mesh poly → |Δy| of its ends, when above 2
        private readonly ConcurrentDictionary<int, float[]> costsByAgent = new ConcurrentDictionary<int, float[]>();
        private readonly ConcurrentBag<NavQueryContext> pool = new ConcurrentBag<NavQueryContext>();
        internal readonly GateState AllOpen;
        internal readonly GateState Defaults;

        public static NavWorld Load(string path, string name = null)
        {
            var file = NavFile.Read(path);
            return new NavWorld(file, name ?? file.Meta.Zone ?? Path.GetFileNameWithoutExtension(path), path);
        }

        public NavWorld(NavFile file, string name, string filePath = null)
        {
            Name = name;
            FilePath = filePath;
            Meta = file.Meta;
            Areas = file.Areas;
            Gates = file.Gates;
            Links = file.Links;
            Seeds = file.Seeds;
            ValidationJson = file.ValidationJson;
            var warnings = new List<string>();

            Mesh = new DtNavMesh();
            var meshParams = file.Params;
            var status = Mesh.Init(in meshParams, NavFile.MAX_VERTS_PER_POLY);
            if (status.Failed())
                throw new InvalidDataException($"{name}: navmesh init failed ({status})");

            // Tiles go back at their saved refs so the refs in GATE/GRPH stay valid.
            var reader = new DtMeshDataReader();
            var tileOrder = new int[file.Tiles.Count];
            for (int k = 0; k < file.Tiles.Count; k++)
            {
                var blob = file.Tiles[k];
                var buffer = new RcByteBuffer(blob.Data);
                buffer.Order(RcByteOrder.LITTLE_ENDIAN);
                DtMeshData data = reader.Read(buffer, NavFile.MAX_VERTS_PER_POLY, false);
                status = Mesh.AddTile(data, 0, blob.TileRef, out long tileRef);
                if (status.Failed())
                    throw new InvalidDataException($"{name}: tile {k} (ref 0x{blob.TileRef:X}) could not be added ({status})");
                if (blob.TileRef != 0 && tileRef != blob.TileRef)
                    throw new InvalidDataException($"{name}: tile {k} got ref 0x{tileRef:X}, saved 0x{blob.TileRef:X}");
                tileOrder[k] = Mesh.GetTileByRef(tileRef).index;
                TileCount++;
                PolyCount += data.header.polyCount;
            }
            file.Tiles.Clear(); // the mesh owns the data now

            int maxTiles = Mesh.GetMaxTiles();

            // Areas: FORMATS §3.1 defaults, then the file's table.
            for (int i = 0; i < DefaultCosts.Length; i++)
                DefaultCosts[i] = 1.0f;
            DefaultCosts[NavArea.WATER] = 2.0f;
            foreach (var a in file.Areas)
                if (a.Id >= 0 && a.Id < NavArea.MAX && a.Cost > 0)
                    DefaultCosts[a.Id] = a.Cost;

            // Off-mesh connection polys by link index (offMeshConUserID = LINK index).
            for (int t = 0; t < maxTiles; t++)
            {
                var tile = Mesh.GetTile(t);
                if (tile?.data?.header == null || tile.data.offMeshCons == null)
                    continue;
                long baseRef = Mesh.GetPolyRefBase(tile);
                foreach (var con in tile.data.offMeshCons)
                {
                    if (!linkPolys.TryGetValue(con.userId, out var list))
                        linkPolys[con.userId] = list = new List<long>();
                    list.Add(baseRef | (uint)con.poly);
                    float rise = Math.Abs(con.pos[1].Y - con.pos[0].Y);
                    if (rise > 2.0f)
                        linkRise[baseRef | (uint)con.poly] = rise;
                }
            }

            // Gates: poly → gate, including the polys of the links each gate controls.
            for (int g = 0; g < Gates.Count; g++)
            {
                if (Gates[g].Index != g)
                    warnings.Add($"gate table not dense at {g} (index {Gates[g].Index})");
                if (!string.IsNullOrEmpty(Gates[g].Id))
                    gateIndex[Gates[g].Id] = g;
            }
            if (Gates.Count > 0)
            {
                gateOfPoly = PerTile(-1);
                for (int g = 0; g < Gates.Count; g++)
                {
                    foreach (long r in Gates[g].Polys)
                        if (!SetPolyValue(gateOfPoly, r, g))
                            warnings.Add($"gate {Gates[g].Id}: poly 0x{r:X} not in the mesh");
                    foreach (int l in Gates[g].Links)
                        if (linkPolys.TryGetValue(l, out var refs))
                            foreach (long r in refs)
                                SetPolyValue(gateOfPoly, r, g);
                }
                foreach (var link in Links)
                    if (link.Gate >= 0 && link.Gate < Gates.Count && linkPolys.TryGetValue(link.Index, out var refs))
                        foreach (long r in refs)
                            SetPolyValue(gateOfPoly, r, link.Gate);
            }

            if (file.Islands != null)
            {
                if (file.Islands.Length == PolyCount)
                    islandOfPoly = InTileOrder(tileOrder, i => (int)file.Islands[i]);
                else
                    warnings.Add($"ISLD has {file.Islands.Length} entries for {PolyCount} polys; ignored");
            }

            if (file.Graph != null)
            {
                if (file.Graph.PolyNode.Length == PolyCount)
                {
                    Graph = file.Graph;
                    nodeOfPoly = InTileOrder(tileOrder, i => Graph.PolyNode[i]);
                    edges = Graph.Edges.OrderBy(e => e.From).ToArray();
                    edgeStart = new int[Graph.Nodes.Length + 1];
                    foreach (var e in edges)
                        edgeStart[e.From + 1]++;
                    for (int i = 0; i < Graph.Nodes.Length; i++)
                        edgeStart[i + 1] += edgeStart[i];
                    // a link is a node between the cells at its ends: the height it spans is theirs
                    int nodes = Graph.Nodes.Length;
                    var lo = new float[nodes];
                    var hi = new float[nodes];
                    for (int n = 0; n < nodes; n++)
                    {
                        lo[n] = float.MaxValue;
                        hi[n] = float.MinValue;
                    }
                    const int linkFlags = (int)(NavFlags.Drop | NavFlags.Link);
                    foreach (var e in edges)
                    {
                        if ((Graph.Nodes[e.From].Flags & linkFlags) != 0)
                        {
                            float y = Graph.Nodes[e.To].Center.Y;
                            lo[e.From] = Math.Min(lo[e.From], y);
                            hi[e.From] = Math.Max(hi[e.From], y);
                        }
                        if ((Graph.Nodes[e.To].Flags & linkFlags) != 0)
                        {
                            float y = Graph.Nodes[e.From].Center.Y;
                            lo[e.To] = Math.Min(lo[e.To], y);
                            hi[e.To] = Math.Max(hi[e.To], y);
                        }
                    }
                    linkNodeRise = new float[nodes];
                    for (int n = 0; n < nodes; n++)
                        linkNodeRise[n] = hi[n] > lo[n] ? hi[n] - lo[n] : 0.0f;
                }
                else
                    warnings.Add($"GRPH maps {file.Graph.PolyNode.Length} polys for {PolyCount}; graph ignored");
            }

            Warnings = warnings;
            AllOpen = GateState.FromDefaults(this, true);
            Defaults = GateState.FromDefaults(this, false);
            pool.Add(NewContext());
        }

        private int[][] PerTile(int fill)
        {
            var a = new int[Mesh.GetMaxTiles()][];
            for (int t = 0; t < a.Length; t++)
            {
                var tile = Mesh.GetTile(t);
                if (tile?.data?.header == null)
                    continue;
                a[t] = new int[tile.data.header.polyCount];
                Array.Fill(a[t], fill);
            }
            return a;
        }

        private int[][] InTileOrder(int[] tileOrder, Func<int, int> value)
        {
            var a = new int[Mesh.GetMaxTiles()][];
            int i = 0;
            foreach (int t in tileOrder)
            {
                var tile = Mesh.GetTile(t);
                int n = tile.data.header.polyCount;
                a[t] = new int[n];
                for (int p = 0; p < n; p++)
                    a[t][p] = value(i++);
            }
            return a;
        }

        private bool SetPolyValue(int[][] table, long polyRef, int value)
        {
            if (!Mesh.IsValidPolyRef(polyRef))
                return false;
            int t = DtDetour.DecodePolyIdTile(polyRef), p = DtDetour.DecodePolyIdPoly(polyRef);
            table[t][p] = value;
            return true;
        }

        #region Lookups

        public NavInstance CreateInstance(string name = null) => new NavInstance(this, name);

        /// <summary>Gate index for an edit-layer id, -1 when unknown.</summary>
        public int GateIndex(string id) => id != null && gateIndex.TryGetValue(id, out int g) ? g : -1;

        /// <summary>Gates whose driver has this field equal to value (e.g. "mapobj", a tree name).</summary>
        public IEnumerable<int> GatesByDriver(string field, string value)
        {
            for (int g = 0; g < Gates.Count; g++)
                if (Gates[g].Driver.TryGetValue(field, out var v) &&
                    v.Split(',').Any(part => string.Equals(part.Trim(), value, StringComparison.OrdinalIgnoreCase)))
                    yield return g;
        }

        internal int GateOfPoly(int tileIndex, int polyIndex)
        {
            if (gateOfPoly == null)
                return -1;
            var t = gateOfPoly[tileIndex];
            return t == null || polyIndex >= t.Length ? -1 : t[polyIndex];
        }

        /// <summary>Height between an off-mesh link's ends (0 for other polys and links under 2).</summary>
        internal float LinkRise(long polyRef) => linkRise.Count > 0 && linkRise.TryGetValue(polyRef, out float r) ? r : 0.0f;

        public int GateOfPoly(long polyRef) =>
            polyRef == 0 ? -1 : GateOfPoly(DtDetour.DecodePolyIdTile(polyRef), DtDetour.DecodePolyIdPoly(polyRef));

        public int NodeOf(long polyRef) => Lookup(nodeOfPoly, polyRef);

        public int IslandOf(long polyRef) => Lookup(islandOfPoly, polyRef);

        private static int Lookup(int[][] table, long polyRef)
        {
            if (table == null || polyRef == 0)
                return -1;
            var t = table[DtDetour.DecodePolyIdTile(polyRef)];
            int p = DtDetour.DecodePolyIdPoly(polyRef);
            return t == null || p >= t.Length ? -1 : t[p];
        }

        public bool IsGroundPoly(long polyRef) =>
            Mesh.GetTileAndPolyByRef(polyRef, out _, out var poly).Succeeded() && poly.GetPolyType() == DtPolyTypes.DT_POLYTYPE_GROUND;

        public int PolyFlags(long polyRef) => Mesh.GetPolyFlags(polyRef, out int f).Succeeded() ? f : 0;

        public int PolyArea(long polyRef) => Mesh.GetPolyArea(polyRef, out int a).Succeeded() ? a : 0;

        internal float[] CostsFor(NavAgent agent)
        {
            if (agent.AreaCosts.Count == 0)
                return DefaultCosts;
            return costsByAgent.GetOrAdd(agent.Key, _ =>
            {
                var c = (float[])DefaultCosts.Clone();
                foreach (var kv in agent.AreaCosts)
                    if (kv.Key >= 0 && kv.Key < c.Length)
                        c[kv.Key] = kv.Value;
                return c;
            });
        }

        internal NavQueryContext Rent() => pool.TryTake(out var ctx) ? ctx : NewContext();

        internal void Return(NavQueryContext ctx) => pool.Add(ctx);

        private NavQueryContext NewContext() => new NavQueryContext(Mesh, Graph?.Nodes.Length ?? 0);

        internal static RcVec3f V(Vector3 v) => new RcVec3f(v.X, v.Y, v.Z);

        internal static Vector3 V(RcVec3f v) => new Vector3(v.X, v.Y, v.Z);

        /// <summary>Ground height of a ground poly at (x, z); false when the point isn't over it.</summary>
        internal bool HeightOn(long polyRef, float x, float z, out float h)
        {
            h = 0;
            if (Mesh.GetTileAndPolyByRef(polyRef, out var tile, out var poly).Failed() || poly.GetPolyType() != DtPolyTypes.DT_POLYTYPE_GROUND)
                return false;
            return Mesh.GetPolyHeight(tile, poly, new RcVec3f(x, 0, z), out h);
        }

        internal bool HeightAlong(long[] corridor, int count, ref int index, float x, float z, out float h)
        {
            int from = Math.Max(0, index - 2), to = Math.Min(count, index + 16);
            for (int j = from; j < to; j++)
                if (HeightOn(corridor[j], x, z, out h))
                {
                    index = j;
                    return true;
                }
            h = 0;
            return false;
        }

        /// <summary>HeightAlong, falling back to points on a corridor poly's edge (where the
        /// point-in-poly test fails).</summary>
        internal bool GroundAlong(NavQueryContext ctx, long[] corridor, int count, ref int index, float x, float z, out float h)
        {
            if (HeightAlong(corridor, count, ref index, x, z, out h))
                return true;
            var p = new RcVec3f(x, 0, z);
            for (int j = Math.Min(count, index + 16) - 1; j >= Math.Max(0, index - 2); j--)
            {
                if (ctx.Query.ClosestPointOnPoly(corridor[j], p, out var c, out _).Failed())
                    continue;
                float dx = c.X - x, dz = c.Z - z;
                if (dx * dx + dz * dz < 0.05f * 0.05f)
                {
                    index = j;
                    h = c.Y;
                    return true;
                }
            }
            return false;
        }

        #endregion

        #region Queries (gate state passed in; NavInstance is the public face)

        /// <summary>The agent's filter with every gate open: where something stands is physical, so ends are
        /// projected on the whole mesh and a closed gate shows up in the route, not as a nearby snap.</summary>
        private IDtQueryFilter Physical(NavQueryContext ctx, NavAgent agent)
        {
            ctx.Other.Set(this, agent, AllOpen);
            return ctx.Other;
        }

        internal NavPoint ProjectWith(NavQueryContext ctx, IDtQueryFilter filter, Vector3 p, float maxVertical, float searchRadius)
        {
            var c = V(p);
            var status = ctx.Query.FindNearestPoly(c, new RcVec3f(searchRadius, maxVertical, searchRadius), filter, out long r, out var pt, out _);
            if (status.Succeeded() && r != 0 && Math.Abs(pt.Y - p.Y) <= maxVertical + 0.01f)
                return new NavPoint(V(pt), r, NavReason.Ok);
            status = ctx.Query.FindNearestPoly(c, new RcVec3f(searchRadius, WIDE_VERTICAL, searchRadius), filter, out r, out pt, out _);
            if (status.Succeeded() && r != 0)
                return new NavPoint(V(pt), r, NavReason.VerticalMismatch);
            return NavPoint.Fail(NavReason.GoalOffMesh);
        }

        /// <summary>The ground under p for this agent: Ok within maxVertical, VerticalMismatch (with the ground
        /// found) when the only ground is further above/below, GoalOffMesh when there is none.</summary>
        internal NavPoint Project(Vector3 p, NavAgent agent, GateState gates, float maxVertical, float searchRadius)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = default(NavPoint);
            try
            {
                ctx.Filter.Set(this, agent, AllOpen);
                return result = ProjectWith(ctx, ctx.Filter, p, maxVertical, searchRadius);
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Project, result.Reason, t0);
            }
        }

        /// <summary>
        /// The floor reached walking from (fromPoly, from) to `to` over shared poly edges only, so a walker
        /// in a tunnel never lands on the ground over it. Ok with `to` on that floor; Partial when the walk
        /// ends further than slack from `to` (a wall, a link crossed, a jump), StartOffMesh when fromPoly is
        /// gone or no longer passes the agent's filter.
        /// </summary>
        internal NavPoint FollowFloor(long fromPoly, Vector3 from, Vector3 to, NavAgent agent, float slack)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = NavPoint.Fail(NavReason.StartOffMesh);
            try
            {
                var filter = Physical(ctx, agent);
                if (!ctx.Query.IsValidPolyRef(fromPoly, filter))
                    return result;
                var status = ctx.Query.MoveAlongSurface(fromPoly, V(from), V(to), filter, out var end, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                if (status.Failed() || n == 0)
                    return result;
                if (NavMath.XZDistance(V(end), to) > slack)
                    return result = NavPoint.Fail(NavReason.Partial);
                long poly = ctx.RayPolys[n - 1];
                float y = HeightOn(poly, end.X, end.Z, out float h) ? h : end.Y;
                return result = new NavPoint(new Vector3(end.X, y, end.Z), poly, NavReason.Ok);
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Project, result.Reason, t0);
            }
        }

        /// <summary>
        /// The floor under p when nothing is carried (a spawn, a teleport, a lost track): the ground nearest
        /// p from `above` over the feet down to maxVertical under them. A floor overhead (a tunnel's roof, a
        /// bridge) is never a candidate; ground further off falls back to Project's answer.
        /// </summary>
        internal NavPoint AcquireFloor(Vector3 p, NavAgent agent, float above, float maxVertical, float searchRadius)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = NavPoint.Fail(NavReason.GoalOffMesh);
            try
            {
                var filter = Physical(ctx, agent);
                float half = (above + maxVertical) * 0.5f;
                var center = new RcVec3f(p.X, p.Y + above - half, p.Z);
                var status = ctx.Query.QueryPolygons(center, new RcVec3f(searchRadius, half, searchRadius), filter, ctx.Polys, out int n, ctx.Polys.Length);
                float best = float.MaxValue;
                var feet = V(p);
                for (int i = 0; status.Succeeded() && i < n; i++)
                {
                    if (ctx.Query.ClosestPointOnPoly(ctx.Polys[i], feet, out var c, out _).Failed() || c.Y > p.Y + above)
                        continue;
                    float d = RcVec3f.DistanceSquared(c, feet);
                    if (d < best)
                    {
                        best = d;
                        result = new NavPoint(V(c), ctx.Polys[i], NavReason.Ok);
                    }
                }
                if (!result.Ok)
                    result = ProjectWith(ctx, filter, p, maxVertical, searchRadius);
                return result;
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Project, result.Reason, t0);
            }
        }

        private static readonly float[] SnapRadii = { 4.0f, 12.0f, 32.0f, 64.0f, 128.0f };
        private const float COLUMN_HALF_HEIGHT = 2000.0f;

        /// <summary>
        /// Puts a spawn-style position on the ground: rows with Y = 0 have no height and take the highest
        /// ground in their column (pruned rooftops are already gone); otherwise the nearest ground, then
        /// the column, then a widening horizontal search. Ok with the ground, or GoalOffMesh.
        /// </summary>
        internal NavPoint Snap(Vector3 p, NavAgent agent, GateState gates)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = NavPoint.Fail(NavReason.GoalOffMesh);
            try
            {
                ctx.Filter.Set(this, agent, AllOpen);
                if (p.Y == 0.0f && HighestAt(ctx, p.X, p.Z, out result))
                    return result;
                result = ProjectWith(ctx, ctx.Filter, p, 4.0f, 2.0f);
                if (result.Ok)
                    return result;
                if (HighestAt(ctx, p.X, p.Z, out result))
                    return result;
                foreach (float r in SnapRadii)
                {
                    var status = ctx.Query.FindNearestPoly(V(p), new RcVec3f(r, COLUMN_HALF_HEIGHT, r), ctx.Filter, out long poly, out var pt, out _);
                    if (status.Succeeded() && poly != 0)
                        return result = new NavPoint(V(pt), poly, NavReason.Ok);
                }
                return result = NavPoint.Fail(NavReason.GoalOffMesh);
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Project, result.Reason, t0);
            }
        }

        private bool HighestAt(NavQueryContext ctx, float x, float z, out NavPoint ground)
        {
            ground = NavPoint.Fail(NavReason.GoalOffMesh);
            var status = ctx.Query.QueryPolygons(new RcVec3f(x, 0, z), new RcVec3f(0.05f, COLUMN_HALF_HEIGHT, 0.05f), ctx.Filter, ctx.Polys, out int n, ctx.Polys.Length);
            if (status.Failed())
                return false;
            bool found = false;
            for (int i = 0; i < n; i++)
                if (HeightOn(ctx.Polys[i], x, z, out float h) && (!found || h > ground.Position.Y))
                {
                    ground = new NavPoint(new Vector3(x, h, z), ctx.Polys[i], NavReason.Ok);
                    found = true;
                }
            return found;
        }

        /// <summary>knownStart: the mover's carried floor (NavFloor); without one the start is the ground
        /// nearest to from.</summary>
        internal NavRoute PlanRoute(NavInstance instance, Vector3 from, Vector3 to, NavAgent agent, RouteOpts opts, NavPoint? knownStart = null)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            NavRoute route = null;
            try
            {
                var gates = instance.Gates;
                ctx.Filter.Set(this, agent, gates);
                route = new NavRoute(this, instance, agent, opts, to, gates.Version);

                var start = knownStart is NavPoint known && known.Ok ? known
                    : ProjectWith(ctx, Physical(ctx, agent), from, opts.MaxVertical, opts.SearchRadius);
                if (!start.Ok)
                {
                    route.Fail(NavReason.StartOffMesh);
                    return route;
                }
                var goal = ProjectWith(ctx, Physical(ctx, agent), to, opts.MaxVertical, opts.SearchRadius);
                if (!goal.Ok)
                {
                    route.Fail(goal.Reason == NavReason.VerticalMismatch ? NavReason.VerticalMismatch : NavReason.GoalOffMesh);
                    return route;
                }
                if (opts.EndRandomRadius > 0.0f &&
                    ctx.Query.FindRandomPointAroundCircle(goal.Poly, V(goal.Position), opts.EndRandomRadius, ctx.Filter, ctx.Rand, out long rr, out var rp).Succeeded() && rr != 0)
                    goal = new NavPoint(V(rp), rr, NavReason.Ok);

                route.Goal = goal;
                PlanStretch(ctx, route, start, gates);
                return route;
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.PlanRoute, route?.Reason ?? NavReason.NoRoute, t0);
            }
        }

        /// <summary>Plans the next stretch of a route from pos (see NavRoute.Advance).</summary>
        internal void AdvanceRoute(NavRoute route, Vector3 pos, NavPoint? knownStart = null)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            try
            {
                var gates = route.Instance.Gates;
                if (gates.Version != route.GateVersion)
                {
                    route.GateVersion = gates.Version;
                    route.NodePath = null;
                }
                ctx.Filter.Set(this, route.Agent, gates);
                var start = knownStart is NavPoint known && known.Ok ? known
                    : ProjectWith(ctx, Physical(ctx, route.Agent), pos, route.Opts.MaxVertical, route.Opts.SearchRadius);
                if (!start.Ok)
                {
                    route.Fail(NavReason.StartOffMesh);
                    return;
                }
                Vector3? previousEnd = route.Points.Count > 0 ? route.Points[route.Points.Count - 1] : (Vector3?)null;
                PlanStretch(ctx, route, start, gates);
                // No progress since the last stretch: Detour can't get further than this.
                if (!route.Complete && previousEnd.HasValue && route.Points.Count > 0 &&
                    Vector3.Distance(previousEnd.Value, route.Points[route.Points.Count - 1]) < 0.5f)
                {
                    route.Complete = true;
                    route.Reason = NavReason.Partial;
                }
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Advance, route.Reason, t0);
            }
        }

        private void PlanStretch(NavQueryContext ctx, NavRoute route, NavPoint start, GateState gates)
        {
            var goal = route.Goal;
            var opts = route.Opts;
            route.BeginStretch(start.Position);

            // 1. short trip in the open: one straight segment
            if (NavMath.XZDistance(start.Position, goal.Position) <= opts.StraightMaxDistance &&
                StraightReaches(ctx, ctx.Filter, start, goal, route.Agent, out int rayCount))
            {
                ctx.Corners[0] = new DtStraightPath(V(start.Position), DtStraightPathFlags.DT_STRAIGHTPATH_START, start.Poly);
                ctx.Corners[1] = new DtStraightPath(V(goal.Position), DtStraightPathFlags.DT_STRAIGHTPATH_END, 0);
                Emit(ctx, route, ctx.RayPolys, rayCount, 2, offset: false);
                route.Complete = true;
                route.Reason = NavReason.Ok;
                route.Stretch = NavRoute.StretchKind.Straight;
                return;
            }

            // 2. component graph: reachability under the gates, then long trips in windows
            if (Graph != null)
            {
                int ns = NodeOf(start.Poly), ng = NodeOf(goal.Poly);
                if (ns >= 0 && ng >= 0)
                {
                    if (!InReach(ns, ng, route.Agent, gates))
                    {
                        route.Fail(InReach(ns, ng, route.Agent, AllOpen) ? NavReason.GateClosed : NavReason.NoRoute);
                        return;
                    }
                    if (CellDistance(ns, ng) > opts.WindowCells)
                    {
                        var path = route.NodePath;
                        int at = path == null ? -1 : path.IndexOf(ns);
                        if (at < 0)
                        {
                            path = route.NodePath = GraphPath(ctx, ns, ng, route.Agent, gates);
                            at = 0;
                            if (path == null)
                            {
                                route.Fail(NavReason.NoRoute);
                                return;
                            }
                        }
                        int k = at + 1;
                        for (int i = at + 1; i < path.Count; i++)
                            if (CellDistance(ns, path[i]) <= opts.WindowCells)
                                k = i;
                        k = Math.Min(k, path.Count - 1);
                        // aim at ground, not at an off-mesh link's own node
                        while (k > at + 1 && !IsGroundPoly(Graph.Nodes[path[k]].CenterPoly))
                            k--;
                        var node = Graph.Nodes[path[k]];
                        var target = new NavPoint(node.Center, node.CenterPoly, NavReason.Ok);
                        DetourStretch(ctx, route, start, target, false, gates);
                        route.Stretch = NavRoute.StretchKind.Window;
                        return;
                    }
                }
            }
            else if (islandOfPoly != null && IslandOf(start.Poly) != IslandOf(goal.Poly))
            {
                route.Fail(NavReason.NoRoute);
                return;
            }

            // 3. local: Detour all the way
            DetourStretch(ctx, route, start, goal, true, gates);
            route.Stretch = NavRoute.StretchKind.Local;
        }

        private void DetourStretch(NavQueryContext ctx, NavRoute route, NavPoint start, NavPoint end, bool final, GateState gates)
        {
            var startPos = V(start.Position);
            var endPos = V(end.Position);
            var status = ctx.Query.FindPath(start.Poly, end.Poly, startPos, endPos, ctx.Filter, ctx.Polys, out int n, ctx.Polys.Length);
            if (status.Failed() || n == 0)
            {
                route.Fail(NavReason.NoRoute);
                return;
            }

            bool partial = status.IsPartial() || ctx.Polys[n - 1] != end.Poly;
            if (partial)
                ctx.Query.ClosestPointOnPoly(ctx.Polys[n - 1], endPos, out endPos, out _);

            status = ctx.Query.FindStraightPath(startPos, endPos, ctx.Polys, n, ctx.Corners, out int corners, ctx.Corners.Length, 0);
            if (status.Failed() || corners == 0)
            {
                route.Fail(NavReason.NoRoute);
                return;
            }
            bool cornersCut = corners >= ctx.Corners.Length && (ctx.Corners[corners - 1].flags & DtStraightPathFlags.DT_STRAIGHTPATH_END) == 0;

            Emit(ctx, route, ctx.Polys, n, corners, offset: true);

            if (!partial && !cornersCut)
            {
                route.Complete = final;
                route.Reason = NavReason.Ok;
            }
            else if (Graph != null || cornersCut)
            {
                // the graph says it's reachable: plan on from the end of this stretch
                route.Complete = false;
                route.Reason = NavReason.Ok;
            }
            else
            {
                route.Complete = true;
                route.Reason = partial && gates.AnyClosed && OpenPathExists(ctx, start, end, route.Agent)
                    ? NavReason.GateClosed : NavReason.Partial;
            }
        }

        /// <summary>Gate check for meshes without a graph: would the path be whole with every gate open?</summary>
        private bool OpenPathExists(NavQueryContext ctx, NavPoint start, NavPoint end, NavAgent agent)
        {
            ctx.Other.Set(this, agent, AllOpen);
            var buf = new long[NavQueryContext.MAX_POLYS];
            var status = ctx.Query.FindPath(start.Poly, end.Poly, V(start.Position), V(end.Position), ctx.Other, buf, out int n, buf.Length);
            return status.Succeeded() && !status.IsPartial() && n > 0 && buf[n - 1] == end.Poly;
        }

        private bool StraightReaches(NavQueryContext ctx, IDtQueryFilter filter, NavPoint start, NavPoint goal, NavAgent agent, out int count)
        {
            var status = ctx.Query.Raycast(start.Poly, V(start.Position), V(goal.Position), filter, out float t, out _, ctx.RayPolys, out count, ctx.RayPolys.Length);
            if (status.Failed() || t < 1.0f || count == 0)
                return false;
            long last = ctx.RayPolys[count - 1];
            if (last == goal.Poly)
                return true;
            return HeightOn(last, goal.Position.X, goal.Position.Z, out float h) && Math.Abs(h - goal.Position.Y) <= agent.Climb + 0.25f;
        }

        /// <summary>Corners → route points: pushes corners out for agents wider than the bake, then
        /// samples every SampleStep with the ground height of the corridor poly under each point.</summary>
        private void Emit(NavQueryContext ctx, NavRoute route, long[] corridor, int corridorCount, int cornerCount, bool offset)
        {
            float extra = route.Agent.Radius - BakedRadius;
            if (offset && extra > 0.01f)
                OffsetCorners(ctx, cornerCount, extra);

            float step = route.Opts.SampleStep;
            int cIdx = 0;
            var prev = V(ctx.Corners[0].pos);
            for (int i = 1; i < cornerCount; i++)
            {
                var cur = V(ctx.Corners[i].pos);
                bool link = (ctx.Corners[i - 1].flags & DtStraightPathFlags.DT_STRAIGHTPATH_OFFMESH_CONNECTION) != 0;
                float seg = NavMath.XZDistance(prev, cur);
                if (step > 0.0f && !link && seg > step)
                {
                    for (float d = step; d < seg - step * 0.25f; d += step)
                    {
                        float t = d / seg;
                        var q = Vector3.Lerp(prev, cur, t);
                        if (GroundAlong(ctx, corridor, corridorCount, ref cIdx, q.X, q.Z, out float h))
                            q.Y = h;
                        route.AddPoint(q);
                    }
                }
                route.AddPoint(cur);
                route.AddCorner(cur, link);
                prev = cur;
            }
        }

        private void OffsetCorners(NavQueryContext ctx, int count, float extra)
        {
            for (int i = 1; i < count - 1; i++)
            {
                if ((ctx.Corners[i].flags & DtStraightPathFlags.DT_STRAIGHTPATH_OFFMESH_CONNECTION) != 0 ||
                    (ctx.Corners[i - 1].flags & DtStraightPathFlags.DT_STRAIGHTPATH_OFFMESH_CONNECTION) != 0)
                    continue;
                var a = ctx.Corners[i - 1].pos;
                var c = ctx.Corners[i].pos;
                var b = ctx.Corners[i + 1].pos;
                var u = Flat(a.X - c.X, a.Z - c.Z);
                var v = Flat(b.X - c.X, b.Z - c.Z);
                float bx = u.X + v.X, bz = u.Y + v.Y;
                float len = MathF.Sqrt(bx * bx + bz * bz);
                if (len < 1e-3f)
                    continue;
                // the bisector of the two legs points into the obstacle the path bends around
                var push = new RcVec3f(-bx / len * extra, 0, -bz / len * extra);
                var target = new RcVec3f(c.X + push.X, c.Y, c.Z + push.Z);
                long poly = ctx.Corners[i].refs;
                if (poly == 0)
                    continue;
                var status = ctx.Query.Raycast(poly, c, target, ctx.Filter, out float t, out _, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                if (status.Failed())
                    continue;
                float f = t >= 1.0f ? 1.0f : Math.Max(0.0f, t * 0.9f);
                var moved = new RcVec3f(c.X + push.X * f, c.Y, c.Z + push.Z * f);
                int idx = n - 1;
                if (n > 0 && GroundAlong(ctx, ctx.RayPolys, n, ref idx, moved.X, moved.Z, out float h))
                    moved.Y = h;
                ctx.Corners[i] = new DtStraightPath(moved, ctx.Corners[i].flags, ctx.Corners[i].refs);
            }
        }

        private static Vector2 Flat(float x, float z)
        {
            float l = MathF.Sqrt(x * x + z * z);
            return l < 1e-6f ? Vector2.Zero : new Vector2(x / l, z / l);
        }

        /// <summary>How far (XZ) a Walk start may be from the mesh before it counts as off it.</summary>
        public float WalkStartSlack => Math.Max(0.5f, BakedRadius);

        private static float FlatDistance(Vector3 a, Vector3 b)
        {
            float dx = a.X - b.X, dz = a.Z - b.Z;
            return MathF.Sqrt(dx * dx + dz * dz);
        }

        internal RayHit Walk(Vector3 from, Vector3 to, NavAgent agent, GateState gates, float maxVertical)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var hit = new RayHit(NavReason.StartOffMesh, 0, from, default);
            try
            {
                ctx.Filter.Set(this, agent, gates);
                if (!float.IsFinite(to.X) || !float.IsFinite(to.Z))
                    return hit = new RayHit(NavReason.NoRoute, 0, from, default);
                var s = ProjectWith(ctx, Physical(ctx, agent), from, Math.Max(maxVertical, 2.0f), 2.0f);
                // standing beside the mesh (players walk closer to walls than the eroded edge, and off
                // it) snaps to the edge, where every outward ray is blocked at once: no answer, not a wall
                if (!s.Ok || FlatDistance(s.Position, from) > WalkStartSlack)
                    return hit = new RayHit(NavReason.StartOffMesh, 0, s.Ok ? s.Position : from, default);
                var sp = V(s.Position);
                var ep = new RcVec3f(to.X, sp.Y, to.Z);
                var status = ctx.Query.Raycast(s.Poly, sp, ep, ctx.Filter, out float t, out var normal, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                if (status.Failed())
                    return hit = new RayHit(NavReason.NoRoute, 0, s.Position, default);
                // Detour lists no polygon when the ray leaves the start polygon through a wall edge at once
                if (n == 0)
                    return hit = new RayHit(NavReason.Ok, 0, s.Position, V(normal));

                float f = Math.Min(1.0f, t);
                var p = new Vector3(sp.X + (ep.X - sp.X) * f, sp.Y, sp.Z + (ep.Z - sp.Z) * f);
                int idx = n - 1;
                bool ground = GroundAlong(ctx, ctx.RayPolys, n, ref idx, p.X, p.Z, out float h);
                if (ground)
                    p.Y = h;
                if (f >= 1.0f && (!ground || Math.Abs(h - to.Y) > maxVertical))
                    return hit = new RayHit(NavReason.VerticalMismatch, 1.0f, p, default);
                return hit = new RayHit(NavReason.Ok, f, p, V(normal));
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Walk, hit.Reason, t0);
            }
        }

        /// <summary>
        /// Sight over the mesh, kept apart from Walk: a mesh edge blocks it unless the ground continues
        /// below it (a ledge looked over), and it is tried both ways so looking up a cliff works too.
        /// Closed gates block; area flags don't. Points off the mesh are visible (no data to say otherwise).
        /// </summary>
        internal bool CanSee(Vector3 eye, Vector3 target, GateState gates)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            bool seen = true;
            try
            {
                ctx.Filter.SetAny(this, gates);
                seen = SightRay(ctx, eye, target) || SightRay(ctx, target, eye);
                return seen;
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.CanSee, seen ? NavReason.Ok : NavReason.NoRoute, t0);
            }
        }

        private bool SightRay(NavQueryContext ctx, Vector3 a, Vector3 b)
        {
            var s = ProjectWith(ctx, ctx.Filter, a, 4.0f, 2.0f);
            if (!s.Ok)
                return true;
            float climb = Meta.WalkableClimb > 0 ? Meta.WalkableClimb : 0.75f;
            long poly = s.Poly;
            var pos = V(s.Position);
            for (int hop = 0; hop < 4; hop++)
            {
                var end = new RcVec3f(b.X, pos.Y, b.Z);
                var status = ctx.Query.Raycast(poly, pos, end, ctx.Filter, out float t, out _, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                if (status.Failed())
                    return false;
                if (t >= 1.0f)
                    return true;

                float hx = pos.X + (end.X - pos.X) * t, hz = pos.Z + (end.Z - pos.Z) * t;
                int idx = n - 1;
                float gy = n > 0 && GroundAlong(ctx, ctx.RayPolys, n, ref idx, hx, hz, out float h) ? h : pos.Y;
                float dx = end.X - pos.X, dz = end.Z - pos.Z;
                float len = MathF.Sqrt(dx * dx + dz * dz);
                if (len < 1e-3f)
                    return true;
                // ground well below the edge, somewhere past it: a drop we look over
                float top = gy - climb, bottom = gy - WIDE_VERTICAL;
                long below = 0;
                var bp = default(RcVec3f);
                foreach (float ahead in SightLookAhead)
                {
                    float px = hx + dx / len * ahead, pz = hz + dz / len * ahead;
                    if (ahead > len * (1.0f - t) + 0.75f)
                        break;
                    var center = new RcVec3f(px, (top + bottom) * 0.5f, pz);
                    var found = ctx.Query.FindNearestPoly(center, new RcVec3f(0.75f, (top - bottom) * 0.5f, 0.75f), ctx.Filter, out below, out bp, out _);
                    if (found.Succeeded() && below != 0 && bp.Y <= top)
                        break;
                    below = 0;
                }
                if (below == 0)
                    return false;
                poly = below;
                pos = bp;
            }
            return false;
        }

        internal NavPoint RandomPoint(Vector3 center, float rMin, float rMax, NavAgent agent, GateState gates)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = NavPoint.Fail(NavReason.StartOffMesh);
            try
            {
                ctx.Filter.Set(this, agent, gates);
                var s = ProjectWith(ctx, Physical(ctx, agent), center, 4.0f, 4.0f);
                if (!s.Ok)
                    return result;
                rMin = Math.Max(0.0f, rMin);
                rMax = Math.Max(rMin + 0.01f, rMax);
                var sp = V(s.Position);
                for (int i = 0; i < 32; i++)
                {
                    // Detour walks polys connected to the center within rMax, so any point it returns is reachable
                    if (ctx.Query.FindRandomPointAroundCircle(s.Poly, sp, rMax, ctx.Filter, ctx.Rand, out long r, out var p).Failed() || r == 0)
                        break;
                    float d = NavMath.XZDistance(V(p), s.Position);
                    if (d >= rMin && d <= rMax)
                        return result = new NavPoint(V(p), r, NavReason.Ok);
                    if (d > rMax)
                    {
                        // the poly reached past the circle: pull the point back onto the ring along the mesh
                        var q = Vector3.Lerp(s.Position, V(p), rMax * 0.999f / d);
                        var hit = ctx.Query.Raycast(s.Poly, sp, new RcVec3f(q.X, sp.Y, q.Z), ctx.Filter, out float t, out _, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                        if (hit.Succeeded() && t >= 1.0f && n > 0 && rMax >= rMin)
                        {
                            int idx = n - 1;
                            if (GroundAlong(ctx, ctx.RayPolys, n, ref idx, q.X, q.Z, out float h))
                                return result = new NavPoint(new Vector3(q.X, h, q.Z), ctx.RayPolys[idx], NavReason.Ok);
                        }
                    }
                }
                return result = NavPoint.Fail(NavReason.NoRoute);
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.RandomPoint, result.Reason, t0);
            }
        }

        internal Reach Reachable(Vector3 a, Vector3 b, NavAgent agent, GateState gates, float maxVertical, float searchRadius)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = new Reach(NavReason.NoRoute);
            try
            {
                ctx.Filter.Set(this, agent, gates);
                var pa = ProjectWith(ctx, Physical(ctx, agent), a, maxVertical, searchRadius);
                if (!pa.Ok)
                    return result = new Reach(NavReason.StartOffMesh);
                var pb = ProjectWith(ctx, Physical(ctx, agent), b, maxVertical, searchRadius);
                if (!pb.Ok)
                    return result = new Reach(pb.Reason == NavReason.VerticalMismatch ? NavReason.VerticalMismatch : NavReason.GoalOffMesh);
                return result = new Reach(ReachPolys(ctx, pa, pb, agent, gates));
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Reachable, result.Reason, t0);
            }
        }

        private NavReason ReachPolys(NavQueryContext ctx, NavPoint a, NavPoint b, NavAgent agent, GateState gates)
        {
            int na = NodeOf(a.Poly), nb = NodeOf(b.Poly);
            if (Graph != null && na >= 0 && nb >= 0)
            {
                if (InReach(na, nb, agent, gates))
                    return NavReason.Ok;
                return InReach(na, nb, agent, AllOpen) ? NavReason.GateClosed : NavReason.NoRoute;
            }
            if (islandOfPoly != null && IslandOf(a.Poly) != IslandOf(b.Poly))
                return NavReason.NoRoute;
            var status = ctx.Query.FindPath(a.Poly, b.Poly, V(a.Position), V(b.Position), ctx.Filter, ctx.Polys, out int n, ctx.Polys.Length);
            if (status.Succeeded() && !status.IsPartial() && n > 0 && ctx.Polys[n - 1] == b.Poly)
                return NavReason.Ok;
            return gates.AnyClosed && OpenPathExists(ctx, a, b, agent) ? NavReason.GateClosed : NavReason.NoRoute;
        }

        internal NavPoint Displace(Vector3 from, Vector3 dir, float dist, NavAgent agent, GateState gates)
        {
            long t0 = NavStats.Now();
            var ctx = Rent();
            var result = NavPoint.Fail(NavReason.StartOffMesh);
            try
            {
                ctx.Filter.Set(this, agent, gates);
                var s = ProjectWith(ctx, Physical(ctx, agent), from, 4.0f, 2.0f);
                if (!s.Ok)
                    return result;
                var d = Flat(dir.X, dir.Z);
                if (d == Vector2.Zero || dist <= 0.0f)
                    return result = s;
                var sp = V(s.Position);
                var ep = new RcVec3f(sp.X + d.X * dist, sp.Y, sp.Z + d.Y * dist);
                var status = ctx.Query.Raycast(s.Poly, sp, ep, ctx.Filter, out float t, out _, ctx.RayPolys, out int n, ctx.RayPolys.Length);
                if (status.Failed() || n == 0)
                    return result = s;
                float travel = t >= 1.0f ? dist : Math.Max(0.0f, t * dist - EDGE_BACKOFF);
                var p = new Vector3(sp.X + d.X * travel, sp.Y, sp.Z + d.Y * travel);
                int idx = n - 1;
                long poly = s.Poly;
                if (GroundAlong(ctx, ctx.RayPolys, n, ref idx, p.X, p.Z, out float h))
                {
                    p.Y = h;
                    poly = ctx.RayPolys[idx];
                }
                return result = new NavPoint(p, poly, t >= 1.0f ? NavReason.Ok : NavReason.Partial);
            }
            finally
            {
                Return(ctx);
                Stats.Record(NavOp.Displace, result.Reason, t0);
            }
        }

        #endregion

        #region Component graph

        private int CellDistance(int a, int b)
        {
            var na = Graph.Nodes[a];
            var nb = Graph.Nodes[b];
            return Math.Max(Math.Abs(na.CellX - nb.CellX), Math.Abs(na.CellZ - nb.CellZ));
        }

        private bool NodePasses(int n, NavAgent agent, GateState gates)
        {
            var node = Graph.Nodes[n];
            if (node.Gate >= 0 && !gates.IsOpen(node.Gate))
                return false;
            if (linkNodeRise != null && linkNodeRise[n] > agent.MaxLinkRise)
                return false;
            return node.Flags == 0 || agent.Passes(node.Flags);
        }

        private static bool EdgePasses(in NavGraphEdge e, NavAgent agent, GateState gates)
        {
            if (e.Gate >= 0 && !gates.IsOpen(e.Gate))
                return false;
            return (e.Flags & (int)agent.Exclude) == 0;
        }

        /// <summary>Is b reachable from a over the graph under these gates? Cached per gate state.</summary>
        internal bool InReach(int a, int b, NavAgent agent, GateState gates)
        {
            if (a == b)
                return true;
            var bits = gates.CachedReach(agent.Key, a, () => ReachSet(a, agent, gates));
            return (bits[b >> 6] & (1UL << (b & 63))) != 0;
        }

        private ulong[] ReachSet(int start, NavAgent agent, GateState gates)
        {
            var bits = new ulong[(Graph.Nodes.Length + 63) / 64];
            var stack = new Stack<int>();
            bits[start >> 6] |= 1UL << (start & 63);
            stack.Push(start);
            while (stack.Count > 0)
            {
                int n = stack.Pop();
                for (int i = edgeStart[n]; i < edgeStart[n + 1]; i++)
                {
                    ref readonly var e = ref edges[i];
                    if ((bits[e.To >> 6] & (1UL << (e.To & 63))) != 0 || !EdgePasses(e, agent, gates) || !NodePasses(e.To, agent, gates))
                        continue;
                    bits[e.To >> 6] |= 1UL << (e.To & 63);
                    stack.Push(e.To);
                }
            }
            return bits;
        }

        /// <summary>A* over the component graph; node path start..goal, or null.</summary>
        internal List<int> GraphPath(NavQueryContext ctx, int start, int goal, NavAgent agent, GateState gates)
        {
            int stamp = ++ctx.StampValue;
            if (stamp == int.MaxValue)
            {
                Array.Clear(ctx.Stamp);
                ctx.StampValue = stamp = 1;
            }
            var goalCenter = Graph.Nodes[goal].Center;
            ctx.Open.Clear();
            ctx.G[start] = 0;
            ctx.Parent[start] = -1;
            ctx.Stamp[start] = stamp;
            ctx.Open.Enqueue(start, Vector3.Distance(Graph.Nodes[start].Center, goalCenter));

            while (ctx.Open.TryDequeue(out int n, out float f))
            {
                if (n == goal)
                {
                    var path = new List<int>();
                    for (int c = goal; c != -1; c = ctx.Parent[c])
                        path.Add(c);
                    path.Reverse();
                    return path;
                }
                float h = Vector3.Distance(Graph.Nodes[n].Center, goalCenter);
                if (f > ctx.G[n] + h + 1e-3f)
                    continue; // stale queue entry
                for (int i = edgeStart[n]; i < edgeStart[n + 1]; i++)
                {
                    ref readonly var e = ref edges[i];
                    if (!EdgePasses(e, agent, gates) || !NodePasses(e.To, agent, gates))
                        continue;
                    float cost = e.Cost > 0 ? e.Cost : Vector3.Distance(Graph.Nodes[n].Center, Graph.Nodes[e.To].Center);
                    float g = ctx.G[n] + cost;
                    if (ctx.Stamp[e.To] == stamp && g >= ctx.G[e.To])
                        continue;
                    ctx.Stamp[e.To] = stamp;
                    ctx.G[e.To] = g;
                    ctx.Parent[e.To] = n;
                    ctx.Open.Enqueue(e.To, g + Vector3.Distance(Graph.Nodes[e.To].Center, goalCenter));
                }
            }
            return null;
        }

        #endregion

        public override string ToString() =>
            $"{Name}: {TileCount} tiles, {PolyCount} polys, {Gates.Count} gates, {Links.Count} links, " +
            (Graph != null ? $"graph {Graph.Nodes.Length} nodes / {Graph.Edges.Length} edges" : "no graph");
    }
}
