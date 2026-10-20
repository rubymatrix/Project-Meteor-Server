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
using System.Numerics;
using System.Threading;

namespace Meteor.Navigation
{
    /// <summary>
    /// Open/closed bit per gate, plus the reachability answers computed under it. Immutable: a change
    /// makes a new state with a higher version, so readers never lock and caches can't go stale.
    /// </summary>
    public sealed class GateState
    {
        private const int MAX_CACHED = 2048;

        public readonly int Version;
        public readonly int Count;
        private readonly ulong[] open;
        private ConcurrentDictionary<long, ulong[]> reach = new ConcurrentDictionary<long, ulong[]>();

        internal GateState(int version, int count, ulong[] open)
        {
            Version = version;
            Count = count;
            this.open = open;
        }

        internal static GateState FromDefaults(NavWorld world, bool allOpen)
        {
            int n = world.Gates.Count;
            var bits = new ulong[(n + 63) / 64];
            for (int i = 0; i < n; i++)
                if (allOpen || world.Gates[i].DefaultOpen)
                    bits[i >> 6] |= 1UL << (i & 63);
            return new GateState(0, n, bits);
        }

        public bool AnyClosed
        {
            get
            {
                for (int i = 0; i < Count; i++)
                    if (!IsOpen(i))
                        return true;
                return false;
            }
        }

        /// <summary>Gates outside the table count as open.</summary>
        public bool IsOpen(int gate) => gate < 0 || gate >= Count || (open[gate >> 6] & (1UL << (gate & 63))) != 0;

        internal GateState With(int gate, bool isOpen)
        {
            var bits = (ulong[])open.Clone();
            if (isOpen)
                bits[gate >> 6] |= 1UL << (gate & 63);
            else
                bits[gate >> 6] &= ~(1UL << (gate & 63));
            return new GateState(Version + 1, Count, bits);
        }

        internal ulong[] CachedReach(int agentKey, int node, Func<ulong[]> compute)
        {
            long key = (long)agentKey << 32 | (uint)node;
            if (reach.TryGetValue(key, out var bits))
                return bits;
            bits = compute();
            if (reach.Count >= MAX_CACHED)
                reach = new ConcurrentDictionary<long, ulong[]>();
            reach[key] = bits;
            return bits;
        }
    }

    /// <summary>
    /// Navigation for one Area (a zone, a private area, a content instance) on a shared NavWorld.
    /// Holds that area's gate state; every query goes through it. Thread-safe.
    /// </summary>
    public sealed class NavInstance
    {
        public readonly NavWorld World;
        public readonly string Name;
        private GateState gates;

        /// <summary>(instance, gate index, open). Raised after the new state is visible.</summary>
        public event Action<NavInstance, int, bool> GateChanged;

        public NavInstance(NavWorld world, string name = null)
        {
            World = world ?? throw new ArgumentNullException(nameof(world));
            Name = name ?? world.Name;
            gates = GateState.FromDefaults(world, false);
        }

        public GateState Gates => Volatile.Read(ref gates);
        public int GateVersion => Gates.Version;

        public bool IsGateOpen(int gate) => Gates.IsOpen(gate);

        public bool IsGateOpen(string id)
        {
            int g = World.GateIndex(id);
            return g >= 0 && Gates.IsOpen(g);
        }

        /// <summary>Opens or closes a gate by its edit-layer id. False when the world has no such gate.</summary>
        public bool SetGate(string id, bool open)
        {
            int g = World.GateIndex(id);
            if (g < 0)
                return false;
            SetGate(g, open);
            return true;
        }

        public void SetGate(int gate, bool open)
        {
            if (gate < 0 || gate >= World.Gates.Count)
                throw new ArgumentOutOfRangeException(nameof(gate));
            while (true)
            {
                var current = Volatile.Read(ref gates);
                if (current.IsOpen(gate) == open)
                    return;
                if (Interlocked.CompareExchange(ref gates, current.With(gate, open), current) == current)
                    break;
            }
            GateChanged?.Invoke(this, gate, open);
        }

        /// <summary>Back to every gate's default state.</summary>
        public void ResetGates()
        {
            for (int g = 0; g < World.Gates.Count; g++)
                SetGate(g, World.Gates[g].DefaultOpen);
        }

        #region Queries

        public NavPoint Project(Vector3 p, NavAgent agent, float maxVertical = 4.0f, float searchRadius = 4.0f) =>
            World.Project(p, agent, Gates, maxVertical, searchRadius);

        /// <summary>Spawn-style snap: Y = 0 means "no height" (highest ground in the column), then nearest
        /// ground, then a widening search up to 128 m.</summary>
        public NavPoint Snap(Vector3 p, NavAgent agent) => World.Snap(p, agent, Gates);

        public NavRoute PlanRoute(Vector3 from, Vector3 to, NavAgent agent, RouteOpts opts = null) =>
            World.PlanRoute(this, from, to, agent, opts ?? RouteOpts.Default);

        /// <summary>A route from a carried floor (NavFloor.Track); a failed start falls back to the ground
        /// nearest from.</summary>
        public NavRoute PlanRoute(NavPoint start, Vector3 from, Vector3 to, NavAgent agent, RouteOpts opts = null) =>
            World.PlanRoute(this, from, to, agent, opts ?? RouteOpts.Default, start);

        public RayHit Walk(Vector3 from, Vector3 to, NavAgent agent, float maxVertical = 2.0f) =>
            World.Walk(from, to, agent, Gates, maxVertical);

        /// <summary>Line of sight over the mesh; closed gates block it, area flags don't.</summary>
        public bool CanSee(Vector3 eye, Vector3 target) => World.CanSee(eye, target, Gates);

        public NavPoint RandomPoint(Vector3 center, float rMin, float rMax, NavAgent agent) =>
            World.RandomPoint(center, rMin, rMax, agent, Gates);

        public Reach Reachable(Vector3 a, Vector3 b, NavAgent agent, float maxVertical = 4.0f, float searchRadius = 4.0f) =>
            World.Reachable(a, b, agent, Gates, maxVertical, searchRadius);

        public NavPoint Displace(Vector3 from, Vector3 dir, float dist, NavAgent agent) =>
            World.Displace(from, dir, dist, agent, Gates);

        #endregion
    }
}
