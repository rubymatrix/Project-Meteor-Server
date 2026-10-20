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
    /// <summary>
    /// The floor a walker stands on, carried from tick to tick instead of looked up from its position.
    /// Each Track walks the last floor to the new position over shared poly edges (MoveAlongSurface),
    /// so a walker in a tunnel can only reach the ground above by walking out of the tunnel's mouth.
    /// The floor is looked up again (AcquireFloor, never upward past a climb) only after Reset, a
    /// position change larger than JUMP, a change of instance or agent, or a walk that ends off the
    /// new position (a link or drop crossed, more than VERTICAL above or below it). Not thread-safe
    /// (one per mover).
    /// </summary>
    public sealed class NavFloor
    {
        /// <summary>How far a tracked position may stand off the mesh: the mesh is eroded by the agent's
        /// radius, and the client's capsule walks closer to walls than that.</summary>
        public const float SLACK = 1.0f;
        /// <summary>A position further than this from the last tracked one was moved, not walked (a spawn,
        /// a warp): look its floor up again.</summary>
        public const float JUMP = 4.0f;
        /// <summary>A walked floor further than this above or below the position isn't the one it stands on
        /// (lifted or dropped in place): look it up. Under the agent height, so the walked floor can never be
        /// the one over or under a tunnel.</summary>
        public const float VERTICAL = 2.0f;
        /// <summary>How far above the feet a looked-up floor may be: about one climb, so a slope or step
        /// still counts but the roof over a tunnel does not.</summary>
        public const float ABOVE = 0.6f;
        /// <summary>How far below the feet a looked-up floor may be.</summary>
        public const float BELOW = 6.0f;
        public const float SEARCH_RADIUS = 2.0f;

        private NavInstance instance;
        private NavAgent agent;
        private Vector3 meshAt;
        private Vector3 at;

        /// <summary>The carried floor poly, 0 when there is none.</summary>
        public long Poly { get; private set; }
        /// <summary>How many times the floor was looked up rather than walked (debugging).</summary>
        public int Acquired { get; private set; }

        /// <summary>Forget the floor: the next Track looks it up (after a teleport).</summary>
        public void Reset() => Poly = 0;

        /// <summary>The floor under pos: walked from the carried one when there is one, else looked up.
        /// Ok with the mesh point under pos and its poly; otherwise the lookup's reason.</summary>
        public NavPoint Track(NavInstance instance, NavAgent agent, Vector3 pos)
        {
            if (Poly != 0 && ReferenceEquals(instance, this.instance) && ReferenceEquals(agent, this.agent)
                && NavMath.XZDistance(pos, at) <= JUMP && Math.Abs(pos.Y - at.Y) <= JUMP)
            {
                var walked = instance.World.FollowFloor(Poly, meshAt, pos, agent, SLACK);
                if (walked.Ok && Math.Abs(walked.Position.Y - pos.Y) <= VERTICAL)
                    return Keep(walked, pos);
            }

            this.instance = instance;
            this.agent = agent;
            Acquired++;
            var found = instance.World.AcquireFloor(pos, agent, ABOVE, BELOW, SEARCH_RADIUS);
            if (found.Ok)
                return Keep(found, pos);
            Poly = 0;
            return found;
        }

        private NavPoint Keep(NavPoint floor, Vector3 pos)
        {
            Poly = floor.Poly;
            meshAt = floor.Position;
            at = pos;
            return floor;
        }

        public override string ToString() => Poly == 0 ? "no floor" : $"floor {Poly:X} ({Acquired} lookups)";
    }
}
