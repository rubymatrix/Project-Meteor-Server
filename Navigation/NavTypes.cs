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
using System.Numerics;

namespace Meteor.Navigation
{
    /// <summary>Recast area ids (FORMATS §3.1).</summary>
    public static class NavArea
    {
        public const int NULL = 0;
        public const int GROUND = 1;
        public const int WATER = 2;
        public const int PLAYER_ONLY = 3;
        public const int GATE_0 = 4;
        public const int GATE_3 = 7;
        public const int LINK = 8;
        public const int LIFT = 9;
        public const int DROP = 10;
        /// <summary>Ground the client's ground probe doesn't confirm (no hit near the mesh, or too little
        /// headroom): players may walk it, server-moved actors may not. Defined for navgen's probe lint.</summary>
        public const int NPC_UNSAFE = 11;
        public const int MAX = 64;
    }

    /// <summary>Poly flags (FORMATS §3.2).</summary>
    [Flags]
    public enum NavFlags : ushort
    {
        None = 0,
        Walk = 0x0001,
        Water = 0x0002,
        PlayerOnly = 0x0004,
        Gate = 0x0008,
        Lift = 0x0010,
        Drop = 0x0020,
        Link = 0x0040,
        /// <summary>Ground built from a seamless neighbour zone's collision past the zone line
        /// (navgen seam overlap): walkable, but it belongs to the other zone.</summary>
        Seam = 0x0080,
        /// <summary>The client's ground probe doesn't land on this poly (navgen 2.3 probe lint, FORMATS §3.2):
        /// server-moved agents leave it out.</summary>
        NpcUnsafe = 0x0100,
        Pruned = 0x8000,
    }

    /// <summary>Why a query came out the way it did. Callers branch on this instead of a bare null.</summary>
    public enum NavReason
    {
        Ok,
        Partial,            // ends at the closest reachable point
        StartOffMesh,
        GoalOffMesh,
        NoRoute,            // both ends on the mesh, nothing connects them for this agent
        GateClosed,         // a route exists with every gate open
        VerticalMismatch,   // ground at that XZ, but outside the vertical band (ledge, rooftop)
    }

    /// <summary>A position on the mesh (or the reason there is none).</summary>
    public readonly struct NavPoint
    {
        public readonly Vector3 Position;
        public readonly long Poly;
        public readonly NavReason Reason;

        public NavPoint(Vector3 position, long poly, NavReason reason)
        {
            Position = position;
            Poly = poly;
            Reason = reason;
        }

        public bool Ok => Reason == NavReason.Ok;

        public static NavPoint Fail(NavReason reason) => new NavPoint(default, 0, reason);

        public override string ToString() => Ok ? $"({Position.X:F2}, {Position.Y:F2}, {Position.Z:F2})" : Reason.ToString();
    }

    /// <summary>Result of a walkability ray along the mesh.</summary>
    public readonly struct RayHit
    {
        public readonly NavReason Reason;
        /// <summary>Fraction of from → to walked before a wall or mesh edge (1 = clear).</summary>
        public readonly float T;
        /// <summary>Where the walk stopped, on the ground.</summary>
        public readonly Vector3 Point;
        public readonly Vector3 Normal;

        public RayHit(NavReason reason, float t, Vector3 point, Vector3 normal)
        {
            Reason = reason;
            T = t;
            Point = point;
            Normal = normal;
        }

        /// <summary>The whole segment is walkable and ends on the same floor as 'to'.</summary>
        public bool Clear => Reason == NavReason.Ok && T >= 1.0f;
    }

    public readonly struct Reach
    {
        public readonly NavReason Reason;
        public Reach(NavReason reason) { Reason = reason; }
        public bool Reachable => Reason == NavReason.Ok;
        public override string ToString() => Reason.ToString();
    }

    /// <summary>Options for PlanRoute.</summary>
    public sealed class RouteOpts
    {
        public static readonly RouteOpts Default = new RouteOpts();

        /// <summary>How far above/below the mesh an end may be before it counts as off it.</summary>
        public float MaxVertical = 4.0f;
        /// <summary>Horizontal search for the nearest poly around each end.</summary>
        public float SearchRadius = 4.0f;
        /// <summary>Trips up to this long (XZ) try a single straight segment first.</summary>
        public float StraightMaxDistance = 24.0f;
        /// <summary>Spacing of the ground points along the route; 0 = corners only.</summary>
        public float SampleStep = 2.0f;
        /// <summary>Graph cells (Chebyshev) around the start planned with Detour in one stretch.</summary>
        public int WindowCells = 2;
        /// <summary>Pick a random end within this radius of the goal (spreads out a pack of chasers).</summary>
        public float EndRandomRadius = 0.0f;
    }

    internal static class NavMath
    {
        public static float XZDistance(Vector3 a, Vector3 b)
        {
            float dx = a.X - b.X, dz = a.Z - b.Z;
            return MathF.Sqrt(dx * dx + dz * dz);
        }
    }
}
