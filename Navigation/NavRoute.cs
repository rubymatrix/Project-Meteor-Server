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

using System.Collections.Generic;
using System.Numerics;

namespace Meteor.Navigation
{
    /// <summary>
    /// A route planned one stretch at a time. Points hold the current stretch (ground points, the
    /// start excluded); when Complete is false, call Advance from near the stretch's end to plan the
    /// next one. Short trips are one straight segment, local trips one Detour path, long trips follow
    /// the component graph and refine a window of cells at a time. Not thread-safe (one per mover).
    /// </summary>
    public sealed class NavRoute
    {
        public enum StretchKind { None, Straight, Local, Window }

        public readonly NavWorld World;
        public readonly NavInstance Instance;
        public readonly NavAgent Agent;
        public readonly RouteOpts Opts;
        /// <summary>The goal as asked for.</summary>
        public readonly Vector3 Target;

        public NavReason Reason { get; internal set; } = NavReason.Ok;
        /// <summary>Nothing more to plan: Points end at the goal (Ok) or as close as it gets.</summary>
        public bool Complete { get; internal set; }
        /// <summary>The goal on the mesh (possibly randomised by EndRandomRadius).</summary>
        public NavPoint Goal { get; internal set; }
        public Vector3 StretchStart { get; private set; }
        public StretchKind Stretch { get; internal set; }
        public int StretchCount { get; private set; }
        /// <summary>Gate version the current stretch was planned under.</summary>
        public int GateVersion { get; internal set; }

        internal List<int> NodePath;
        private readonly List<Vector3> points = new List<Vector3>();
        private readonly List<Vector3> corners = new List<Vector3>();

        public IReadOnlyList<Vector3> Points => points;
        /// <summary>The straight-path corners of the current stretch (after corner offsets).</summary>
        public IReadOnlyList<Vector3> Corners => corners;
        public IReadOnlyList<int> GraphNodes => NodePath;

        /// <summary>A route (complete or not) with points to walk.</summary>
        public bool Ok => (Reason == NavReason.Ok || Reason == NavReason.Partial) && points.Count > 0;

        /// <summary>The instance's gates changed since this stretch was planned.</summary>
        public bool Stale => Instance.GateVersion != GateVersion;

        internal NavRoute(NavWorld world, NavInstance instance, NavAgent agent, RouteOpts opts, Vector3 target, int gateVersion)
        {
            World = world;
            Instance = instance;
            Agent = agent;
            Opts = opts;
            Target = target;
            GateVersion = gateVersion;
        }

        /// <summary>Plans the next stretch from pos (the mover's position near the end of this one).
        /// Gate changes since planning re-run the graph search. False when there is nothing to plan or
        /// the new stretch failed (see Reason).</summary>
        public bool Advance(Vector3 pos)
        {
            if (Complete && !Stale)
                return false;
            World.AdvanceRoute(this, pos);
            return Ok;
        }

        /// <summary>Advance from a carried floor (NavFloor.Track); a failed start falls back to the ground
        /// nearest pos.</summary>
        public bool Advance(NavPoint start, Vector3 pos)
        {
            if (Complete && !Stale)
                return false;
            World.AdvanceRoute(this, pos, start);
            return Ok;
        }

        public float Length
        {
            get
            {
                float len = 0;
                var prev = StretchStart;
                foreach (var p in points)
                {
                    len += Vector3.Distance(prev, p);
                    prev = p;
                }
                return len;
            }
        }

        internal void BeginStretch(Vector3 start)
        {
            points.Clear();
            corners.Clear();
            StretchStart = start;
            StretchCount++;
            Complete = false;
            Reason = NavReason.Ok;
            Stretch = StretchKind.None;
        }

        internal void AddPoint(Vector3 p) => points.Add(p);

        internal void AddCorner(Vector3 p, bool link) => corners.Add(p);

        internal void Fail(NavReason reason)
        {
            points.Clear();
            corners.Clear();
            Reason = reason;
            Complete = true;
        }

        public override string ToString() =>
            $"{Reason} {(Complete ? "complete" : "partial-plan")} {Stretch} stretch {StretchCount}, {points.Count} points, {Length:F1}m";
    }
}
