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
using System.Threading;
using DotRecast.Core.Numerics;
using DotRecast.Detour;

namespace Meteor.Navigation
{
    /// <summary>
    /// What an actor may cross and how it is sized. Immutable; build variants with With().
    /// PRUNED polys are excluded for every agent.
    /// </summary>
    public sealed class NavAgent
    {
        private static int nextKey;

        public readonly string Name;
        /// <summary>Unique per instance; keys the per-agent caches.</summary>
        public readonly int Key;
        public readonly float Radius;
        public readonly float Height;
        public readonly float Climb;
        public readonly NavFlags Include;
        public readonly NavFlags Exclude;
        /// <summary>Area id → cost; areas not listed use the world's AREA table.</summary>
        public readonly IReadOnlyDictionary<int, float> AreaCosts;
        /// <summary>Off-mesh links (drops, climbs) whose ends differ in height by more than this are closed to the
        /// agent. Server-moved characters are walked by the client, whose ground probe reaches 10 below.</summary>
        public readonly float MaxLinkRise;

        public NavAgent(string name, float radius, float height, float climb, NavFlags include, NavFlags exclude,
            IReadOnlyDictionary<int, float> areaCosts = null, float maxLinkRise = float.PositiveInfinity)
        {
            MaxLinkRise = maxLinkRise;
            Name = name;
            Key = Interlocked.Increment(ref nextKey);
            Radius = radius;
            Height = height;
            Climb = climb;
            Include = include;
            Exclude = exclude | NavFlags.Pruned;
            AreaCosts = areaCosts ?? new Dictionary<int, float>();
        }

        public NavAgent With(string name = null, float? radius = null, NavFlags? include = null, NavFlags? exclude = null,
            IReadOnlyDictionary<int, float> areaCosts = null)
        {
            return new NavAgent(name ?? Name, radius ?? Radius, Height, Climb, include ?? Include, exclude ?? Exclude, areaCosts ?? AreaCosts, MaxLinkRise);
        }

        /// <summary>Detour's include/exclude test on a poly (or graph node/edge) flag set.</summary>
        public bool Passes(int flags) => (flags & (int)Include) != 0 && (flags & (int)Exclude) == 0;

        private const NavFlags Ground = NavFlags.Walk | NavFlags.Water | NavFlags.Gate | NavFlags.Link;

        /// <summary>Left out for every server-moved actor: ground where the client's probe would draw it on
        /// something else (a cave ceiling, nothing at all).</summary>
        private const NavFlags ProbeUnsafe = NavFlags.NpcUnsafe;

        /// <summary>Monsters: no player-only ground, no lifts.</summary>
        public static readonly NavAgent Mob = new NavAgent("Mob", 0.5f, 2.0f, 0.75f,
            Ground | NavFlags.Drop, NavFlags.PlayerOnly | NavFlags.Lift | ProbeUnsafe, maxLinkRise: CLIENT_LINK_RISE);

        /// <summary>Highest link a client-walked character can take: inside the client probe's 10-yalm reach.</summary>
        public const float CLIENT_LINK_RISE = 9.5f;

        /// <summary>Escorted npcs: lifts yes, jumping off ledges no.</summary>
        public static readonly NavAgent Escort = new NavAgent("Escort", 0.5f, 2.0f, 0.75f,
            Ground | NavFlags.Lift, NavFlags.PlayerOnly | NavFlags.Drop | ProbeUnsafe);

        /// <summary>Allies, trusts and pets follow the party through lifts and drops.</summary>
        public static readonly NavAgent Ally = new NavAgent("Ally", 0.5f, 2.0f, 0.75f,
            Ground | NavFlags.Lift | NavFlags.Drop, NavFlags.PlayerOnly | ProbeUnsafe, maxLinkRise: CLIENT_LINK_RISE);

        /// <summary>Player bots go wherever a player can, except where other clients would draw them off it.</summary>
        public static readonly NavAgent Bot = new NavAgent("Bot", 0.5f, 2.0f, 0.75f,
            Ground | NavFlags.Lift | NavFlags.Drop | NavFlags.PlayerOnly, ProbeUnsafe);

        /// <summary>Everything a player may cross (tests, GM tools).</summary>
        public static readonly NavAgent Player = new NavAgent("Player", 0.5f, 2.0f, 0.75f,
            Ground | NavFlags.Lift | NavFlags.Drop | NavFlags.PlayerOnly, NavFlags.None);

        public override string ToString() => Name;
    }

    /// <summary>
    /// Detour filter for one agent under one gate state. One per pooled query context, re-pointed per
    /// query, so it never allocates.
    /// </summary>
    internal sealed class NavFilter : IDtQueryFilter
    {
        private NavWorld world;
        private GateState gates;
        private float[] costs;
        private int include, exclude;
        private float maxLinkRise = float.PositiveInfinity;

        public void Set(NavWorld world, NavAgent agent, GateState gates)
        {
            this.world = world;
            this.gates = gates;
            costs = world.CostsFor(agent);
            include = (int)agent.Include;
            exclude = (int)agent.Exclude;
            maxLinkRise = agent.MaxLinkRise;
        }

        /// <summary>Everything but pruned polys (sight, gate-agnostic reachability).</summary>
        public void SetAny(NavWorld world, GateState gates)
        {
            this.world = world;
            this.gates = gates;
            costs = world.DefaultCosts;
            include = 0xFFFF;
            exclude = (int)NavFlags.Pruned;
            maxLinkRise = float.PositiveInfinity;
        }

        public bool PassFilter(long refs, DtMeshTile tile, DtPoly poly)
        {
            int f = poly.flags;
            if ((f & include) == 0 || (f & exclude) != 0)
                return false;
            if (maxLinkRise < float.PositiveInfinity && world.LinkRise(refs) > maxLinkRise)
                return false;
            if (gates != null)
            {
                int g = world.GateOfPoly(tile.index, poly.index);
                if (g >= 0 && !gates.IsOpen(g))
                    return false;
            }
            return true;
        }

        public float GetCost(RcVec3f pa, RcVec3f pb, long prevRef, DtMeshTile prevTile, DtPoly prevPoly,
            long curRef, DtMeshTile curTile, DtPoly curPoly, long nextRef, DtMeshTile nextTile, DtPoly nextPoly)
        {
            return RcVec3f.Distance(pa, pb) * costs[curPoly.GetArea()];
        }
    }
}
