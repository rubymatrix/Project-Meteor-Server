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
using System.Threading;

namespace Meteor.Navigation
{
    /// <summary>A probe answer: the surface's y, or no hit.</summary>
    public readonly struct ProbeHit
    {
        public static readonly ProbeHit Miss = new ProbeHit(0, -1, -1);

        public readonly float Y;
        /// <summary>Triangle index in the world, -1 on a miss.</summary>
        public readonly int Triangle;
        /// <summary>Index into CollisionWorld.Groups, -1 on a miss.</summary>
        public readonly int Group;

        public ProbeHit(float y, int triangle, int group)
        {
            Y = y;
            Triangle = triangle;
            Group = group;
        }

        public bool Hit => Triangle >= 0;

        public override string ToString() => Hit ? Y.ToString("F3") : "miss";
    }

    /// <summary>A collision group of one source zone.</summary>
    public sealed class CollisionGroup
    {
        public int Index;
        public string Zone;
        public XcolGroup Source;
        /// <summary>Slot in CollisionState for switchable groups, -1 for static ones.</summary>
        public int DynamicSlot = -1;

        public string Name => Source.Name;
        public override string ToString() => Zone + ":" + Name;
    }

    /// <summary>
    /// Which switchable groups are present. Immutable; a change makes a new state, so readers never lock.
    /// </summary>
    public sealed class CollisionState
    {
        public readonly int Version;
        public readonly int Count;
        private readonly ulong[] present;

        internal CollisionState(int version, int count, ulong[] present)
        {
            Version = version;
            Count = count;
            this.present = present;
        }

        public bool IsPresent(int slot) => slot < 0 || slot >= Count || (present[slot >> 6] & (1UL << (slot & 63))) != 0;

        public CollisionState With(int slot, bool isPresent)
        {
            if (slot < 0 || slot >= Count || IsPresent(slot) == isPresent)
                return this;
            var bits = (ulong[])present.Clone();
            if (isPresent)
                bits[slot >> 6] |= 1UL << (slot & 63);
            else
                bits[slot >> 6] &= ~(1UL << (slot & 63));
            return new CollisionState(Version + 1, Count, bits);
        }

        internal ulong[] Bits => present;
    }

    /// <summary>
    /// The surfaces the client's ground probe sees (ClientProbe), from the collision export: only those
    /// triangles, in an XZ bounding volume hierarchy for vertical rays. Switchable groups keep their slot
    /// and drop out while absent, the way the client disables a hidden tree's body. Immutable and
    /// thread-safe; one per zone, shared by every area on it.
    /// </summary>
    public sealed class CollisionWorld
    {
        private const int LEAF_SIZE = 8;
        private const int MAX_DEPTH = 64;
        // Barycentric slack on triangle edges, so a ray down a shared edge hits one of the two triangles.
        private const double EDGE_EPSILON = 1e-7;
        // A surface this close above the floor is the floor itself (its neighbours at a seam), not a ceiling.
        public const float HEADROOM_EPSILON = 0.01f;

        public readonly string Name;
        public readonly IReadOnlyList<CollisionGroup> Groups;
        public readonly IReadOnlyList<CollisionGroup> DynamicGroups;
        /// <summary>Every group present except those whose groups.json says "initial": "off".</summary>
        public readonly CollisionState Defaults;
        /// <summary>Triangles read from the sources, before keeping only probe-visible ones.</summary>
        public readonly int SourceTriangles;

        private readonly float[] verts;     // x, y, z
        private readonly int[] tris;        // a, b, c (BVH leaf order)
        private readonly ushort[] triGroup; // index into Groups
        private readonly float[] nodeBox;   // minX, minZ, maxX, maxZ, minY, maxY
        private readonly int[] nodeData;    // internal: right child, 0 (left = node + 1); leaf: first triangle, count
        private readonly short[] groupSlot;
        private readonly Dictionary<string, int> slotByName = new Dictionary<string, int>(StringComparer.Ordinal);

        private sealed class GateCache
        {
            public NavWorld Nav;
            public int[][] Slots;   // per gate
            public GateState Gates;
            public CollisionState State;
        }
        private GateCache gateCache;

        public int TriangleCount => triGroup.Length;
        public int VertexCount => verts.Length / 3;
        public int NodeCount => nodeData.Length / 2;
        public long MemoryBytes => verts.Length * 4L + tris.Length * 4L + triGroup.Length * 2L + nodeBox.Length * 4L + nodeData.Length * 4L;

        /// <summary>Loads static.xcol + groups.json from each zone folder (own zone first, then seam neighbours).</summary>
        public static CollisionWorld LoadZones(string name, params string[] zoneDirs)
        {
            var sources = new List<(string, XcolFile)>();
            foreach (var dir in zoneDirs)
                sources.Add((Path.GetFileName(Path.GetFullPath(dir).TrimEnd(Path.DirectorySeparatorChar)), XcolReader.LoadZone(dir)));
            return new CollisionWorld(name, sources);
        }

        public CollisionWorld(string name, IEnumerable<(string zone, XcolFile file)> sources)
        {
            Name = name;
            var groups = new List<CollisionGroup>();
            var dynamic = new List<CollisionGroup>();
            var vertList = new List<float>();
            var triList = new List<int>();
            var groupList = new List<ushort>();

            foreach (var (zone, x) in sources)
            {
                SourceTriangles += x.TriangleCount;
                int groupBase = groups.Count;
                int maxGroup = 0;
                for (int t = 0; t < x.TriangleCount; t++)
                    maxGroup = Math.Max(maxGroup, x.Group[t] + 1);
                for (int g = 0; g < Math.Max(maxGroup, x.Groups.Count); g++)
                {
                    var src = g < x.Groups.Count && x.Groups[g].Id == g ? x.Groups[g] : x.Groups.Find(e => e.Id == g)
                        ?? new XcolGroup { Id = g, Name = "group" + g };
                    var cg = new CollisionGroup { Index = groups.Count, Zone = zone, Source = src };
                    if (src.Dynamic)
                    {
                        cg.DynamicSlot = dynamic.Count;
                        dynamic.Add(cg);
                        if (src.Name != null && !slotByName.ContainsKey(src.Name))
                            slotByName[src.Name] = cg.DynamicSlot;
                    }
                    groups.Add(cg);
                }
                if (groups.Count > ushort.MaxValue)
                    throw new InvalidDataException($"{name}: more than {ushort.MaxValue} collision groups");

                var remap = new int[x.VertexCount];
                Array.Fill(remap, -1);
                var v = x.Vertices;
                for (int t = 0; t < x.TriangleCount; t++)
                {
                    if (!ClientProbe.IsVisible(x.Material[t], x.Kind[t]))
                        continue;
                    int a = x.Indices[t * 3], b = x.Indices[t * 3 + 1], c = x.Indices[t * 3 + 2];
                    // Zero XZ area: a vertical ray can't hit it.
                    if (Den(v[a * 3], v[a * 3 + 2], v[b * 3], v[b * 3 + 2], v[c * 3], v[c * 3 + 2]) == 0)
                        continue;
                    for (int k = 0; k < 3; k++)
                    {
                        int i = x.Indices[t * 3 + k];
                        if (remap[i] < 0)
                        {
                            remap[i] = vertList.Count / 3;
                            vertList.Add(v[i * 3]);
                            vertList.Add(v[i * 3 + 1]);
                            vertList.Add(v[i * 3 + 2]);
                        }
                        triList.Add(remap[i]);
                    }
                    groupList.Add((ushort)(groupBase + x.Group[t]));
                }
            }

            Groups = groups;
            DynamicGroups = dynamic;
            groupSlot = new short[groups.Count];
            for (int g = 0; g < groups.Count; g++)
                groupSlot[g] = (short)groups[g].DynamicSlot;

            var bits = new ulong[(dynamic.Count + 63) / 64];
            for (int s = 0; s < dynamic.Count; s++)
                if (!string.Equals(dynamic[s].Source.Initial, "off", StringComparison.OrdinalIgnoreCase))
                    bits[s >> 6] |= 1UL << (s & 63);
            Defaults = new CollisionState(0, dynamic.Count, bits);

            verts = vertList.ToArray();
            BuildBvh(verts, triList.ToArray(), groupList.ToArray(), out tris, out triGroup, out nodeBox, out nodeData);
        }

        #region Queries

        /// <summary>
        /// The client's probe from a drawn y: the nearest surface going down from yFrom + 2 to yFrom − 10,
        /// back faces included. A miss means the client keeps the actor's y.
        /// </summary>
        public ProbeHit Probe(float x, float z, float yFrom, CollisionState state = null)
        {
            // Same float steps as the client: start = y + 2, hit when 0 <= t < length.
            float top = yFrom + ClientProbe.RayUp;
            float bottom = top - (ClientProbe.RayDown + ClientProbe.RayUp);
            return RayDown(x, z, top, bottom, state);
        }

        /// <summary>True when no visible surface lies in (floorY, floorY + h] at x, z.</summary>
        public bool Headroom(float x, float z, float floorY, float h, CollisionState state = null) =>
            !RayDown(x, z, floorY + h, floorY + HEADROOM_EPSILON, state).Hit;

        /// <summary>Every visible surface at x, z, highest first (diagnostics). Triangles meeting at the
        /// point within HEADROOM_EPSILON count as one surface.</summary>
        public List<ProbeHit> Floors(float x, float z, CollisionState state = null)
        {
            var hits = new List<ProbeHit>();
            Visit(x, z, float.PositiveInfinity, float.NegativeInfinity, state ?? Defaults, hits, out _);
            hits.Sort((a, b) => b.Y.CompareTo(a.Y));
            var surfaces = new List<ProbeHit>(hits.Count);
            foreach (var h in hits)
                if (surfaces.Count == 0 || surfaces[surfaces.Count - 1].Y - h.Y > HEADROOM_EPSILON)
                    surfaces.Add(h);
            return surfaces;
        }

        /// <summary>Highest visible surface with yBottom &lt; y &lt;= yTop.</summary>
        public ProbeHit RayDown(float x, float z, float yTop, float yBottom, CollisionState state = null)
        {
            Visit(x, z, yTop, yBottom, state ?? Defaults, null, out var best);
            return best;
        }

        private void Visit(float x, float z, float yTop, float yBottom, CollisionState state, List<ProbeHit> all, out ProbeHit best)
        {
            best = ProbeHit.Miss;
            if (nodeData.Length == 0)
                return;
            float bestY = float.NegativeInfinity;
            Span<int> stack = stackalloc int[MAX_DEPTH + 2];
            int sp = 0;
            stack[sp++] = 0;
            while (sp > 0)
            {
                int n = stack[--sp];
                int b = n * 6;
                if (x < nodeBox[b] || z < nodeBox[b + 1] || x > nodeBox[b + 2] || z > nodeBox[b + 3] ||
                    nodeBox[b + 5] <= yBottom || nodeBox[b + 4] > yTop)
                    continue;
                int count = nodeData[n * 2 + 1];
                if (count == 0)
                {
                    stack[sp++] = nodeData[n * 2];
                    stack[sp++] = n + 1;
                    continue;
                }
                int first = nodeData[n * 2];
                for (int t = first; t < first + count; t++)
                {
                    if (!HitTriangle(t, x, z, out float y) || y > yTop || y <= yBottom)
                        continue;
                    int g = triGroup[t];
                    if (!state.IsPresent(groupSlot[g]))
                        continue;
                    if (all != null)
                        all.Add(new ProbeHit(y, t, g));
                    else if (y > bestY)
                    {
                        bestY = y;
                        best = new ProbeHit(y, t, g);
                    }
                }
            }
        }

        private bool HitTriangle(int t, float x, float z, out float y)
        {
            int a = tris[t * 3] * 3, b = tris[t * 3 + 1] * 3, c = tris[t * 3 + 2] * 3;
            double ax = verts[a], az = verts[a + 2];
            double v0x = verts[b] - ax, v0z = verts[b + 2] - az;
            double v1x = verts[c] - ax, v1z = verts[c + 2] - az;
            double px = x - ax, pz = z - az;
            double den = v0x * v1z - v1x * v0z;
            double u = (px * v1z - v1x * pz) / den;
            double v = (v0x * pz - px * v0z) / den;
            if (u < -EDGE_EPSILON || v < -EDGE_EPSILON || u + v > 1 + EDGE_EPSILON)
            {
                y = 0;
                return false;
            }
            double ay = verts[a + 1];
            y = (float)(ay + u * (verts[b + 1] - ay) + v * (verts[c + 1] - ay));
            return true;
        }

        private static double Den(double ax, double az, double bx, double bz, double cx, double cz) =>
            (bx - ax) * (cz - az) - (cx - ax) * (bz - az);

        #endregion

        #region Switchable groups

        /// <summary>Slot of a switchable group by its groups.json name, -1 if none.</summary>
        public int DynamicSlot(string groupName) => groupName != null && slotByName.TryGetValue(groupName, out int s) ? s : -1;

        /// <summary>Group of a hit (null on a miss).</summary>
        public CollisionGroup GroupOf(ProbeHit hit) => hit.Group >= 0 ? Groups[hit.Group] : null;

        /// <summary>The collision state an area's gates imply.</summary>
        public CollisionState StateFor(NavInstance instance) => instance == null ? Defaults : StateFor(instance.World, instance.Gates);

        /// <summary>
        /// Switchable groups follow the navmesh gate bound to them (an edit-layer gate's group, or the
        /// implicit "auto:&lt;group&gt;" gate). Open = passable, so a blocking tree is absent while its gate is
        /// open and a surface tree is present. Unbound groups keep their default.
        /// </summary>
        public CollisionState StateFor(NavWorld nav, GateState gates)
        {
            if (nav == null || gates == null || DynamicGroups.Count == 0)
                return Defaults;
            var cache = Volatile.Read(ref gateCache);
            if (cache != null && cache.Nav == nav && cache.Gates == gates)
                return cache.State;

            int[][] slots = cache != null && cache.Nav == nav ? cache.Slots : BindGates(nav);
            var bits = (ulong[])Defaults.Bits.Clone();
            for (int g = 0; g < slots.Length; g++)
            {
                if (slots[g] == null)
                    continue;
                bool open = gates.IsOpen(g);
                bool present = string.Equals(nav.Gates[g].Role, "block", StringComparison.OrdinalIgnoreCase) ? !open : open;
                foreach (int s in slots[g])
                {
                    if (present)
                        bits[s >> 6] |= 1UL << (s & 63);
                    else
                        bits[s >> 6] &= ~(1UL << (s & 63));
                }
            }
            var state = new CollisionState(gates.Version, DynamicGroups.Count, bits);
            Volatile.Write(ref gateCache, new GateCache { Nav = nav, Slots = slots, Gates = gates, State = state });
            return state;
        }

        /// <summary>Gates of nav that bind a switchable group here.</summary>
        public int BoundGates(NavWorld nav)
        {
            int n = 0;
            foreach (var s in BindGates(nav))
                if (s != null)
                    n++;
            return n;
        }

        private int[][] BindGates(NavWorld nav)
        {
            var slots = new int[nav.Gates.Count][];
            for (int g = 0; g < nav.Gates.Count; g++)
            {
                var gate = nav.Gates[g];
                string group = gate.Group;
                if (group == null && gate.Id != null && gate.Id.StartsWith("auto:", StringComparison.Ordinal))
                    group = gate.Id.Substring(5);
                int s = DynamicSlot(group);
                if (s >= 0)
                    slots[g] = new[] { s };
            }
            return slots;
        }

        #endregion

        #region BVH

        private static void BuildBvh(float[] verts, int[] inTris, ushort[] inGroups, out int[] outTris, out ushort[] outGroups,
            out float[] boxes, out int[] data)
        {
            int n = inGroups.Length;
            outTris = new int[n * 3];
            outGroups = new ushort[n];
            if (n == 0)
            {
                boxes = Array.Empty<float>();
                data = Array.Empty<int>();
                return;
            }
            var b = new BvhBuilder(verts, inTris, n);
            b.Build(0, n, 0);
            for (int i = 0; i < n; i++)
            {
                int t = b.Order[i];
                outTris[i * 3] = inTris[t * 3];
                outTris[i * 3 + 1] = inTris[t * 3 + 1];
                outTris[i * 3 + 2] = inTris[t * 3 + 2];
                outGroups[i] = inGroups[t];
            }
            boxes = b.Boxes.ToArray();
            data = b.Data.ToArray();
        }

        /// <summary>Top-down build: split at the middle of the centroid bounds on the wider XZ axis.</summary>
        private sealed class BvhBuilder
        {
            public readonly int[] Order;
            public readonly List<float> Boxes = new List<float>();
            public readonly List<int> Data = new List<int>();
            private readonly float[] box;       // per triangle: minX, minZ, maxX, maxZ, minY, maxY
            private readonly float[] cx, cz;

            public BvhBuilder(float[] verts, int[] tris, int n)
            {
                Order = new int[n];
                box = new float[n * 6];
                cx = new float[n];
                cz = new float[n];
                for (int t = 0; t < n; t++)
                {
                    Order[t] = t;
                    float x0 = float.MaxValue, z0 = float.MaxValue, y0 = float.MaxValue;
                    float x1 = float.MinValue, z1 = float.MinValue, y1 = float.MinValue;
                    for (int k = 0; k < 3; k++)
                    {
                        int v = tris[t * 3 + k] * 3;
                        x0 = Math.Min(x0, verts[v]); x1 = Math.Max(x1, verts[v]);
                        y0 = Math.Min(y0, verts[v + 1]); y1 = Math.Max(y1, verts[v + 1]);
                        z0 = Math.Min(z0, verts[v + 2]); z1 = Math.Max(z1, verts[v + 2]);
                    }
                    int o = t * 6;
                    box[o] = x0; box[o + 1] = z0; box[o + 2] = x1; box[o + 3] = z1; box[o + 4] = y0; box[o + 5] = y1;
                    cx[t] = (x0 + x1) * 0.5f;
                    cz[t] = (z0 + z1) * 0.5f;
                }
            }

            public int Build(int start, int end, int depth)
            {
                int node = Data.Count / 2;
                float x0 = float.MaxValue, z0 = float.MaxValue, y0 = float.MaxValue;
                float x1 = float.MinValue, z1 = float.MinValue, y1 = float.MinValue;
                float mx0 = float.MaxValue, mz0 = float.MaxValue, mx1 = float.MinValue, mz1 = float.MinValue;
                for (int i = start; i < end; i++)
                {
                    int o = Order[i] * 6;
                    x0 = Math.Min(x0, box[o]); z0 = Math.Min(z0, box[o + 1]);
                    x1 = Math.Max(x1, box[o + 2]); z1 = Math.Max(z1, box[o + 3]);
                    y0 = Math.Min(y0, box[o + 4]); y1 = Math.Max(y1, box[o + 5]);
                    float px = cx[Order[i]], pz = cz[Order[i]];
                    mx0 = Math.Min(mx0, px); mx1 = Math.Max(mx1, px);
                    mz0 = Math.Min(mz0, pz); mz1 = Math.Max(mz1, pz);
                }
                Boxes.Add(x0); Boxes.Add(z0); Boxes.Add(x1); Boxes.Add(z1); Boxes.Add(y0); Boxes.Add(y1);
                Data.Add(start); Data.Add(end - start);

                bool alongX = mx1 - mx0 >= mz1 - mz0;
                float extent = alongX ? mx1 - mx0 : mz1 - mz0;
                if (end - start <= LEAF_SIZE || depth >= MAX_DEPTH || extent <= 0)
                    return node;

                float mid = alongX ? (mx0 + mx1) * 0.5f : (mz0 + mz1) * 0.5f;
                var c = alongX ? cx : cz;
                int i0 = start, i1 = end - 1;
                while (i0 <= i1)
                {
                    if (c[Order[i0]] < mid)
                        i0++;
                    else
                    {
                        (Order[i0], Order[i1]) = (Order[i1], Order[i0]);
                        i1--;
                    }
                }
                if (i0 == start || i0 == end)
                    i0 = (start + end) / 2;

                Build(start, i0, depth + 1);
                int right = Build(i0, end, depth + 1);
                Data[node * 2] = right;
                Data[node * 2 + 1] = 0;
                return node;
            }
        }

        #endregion
    }
}
