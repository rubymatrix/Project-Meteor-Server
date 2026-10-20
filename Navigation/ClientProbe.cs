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

namespace Meteor.Navigation
{
    /// <summary>
    /// The client's ground probe for remote actors (mobs, NPCs, server-driven Player-class actors):
    /// CharaActor_probeGround casts a ray straight down from above the drawn y and the snap takes the
    /// nearest hit, either winding. It is the only collision those actors have. Retail starts the ray
    /// 2 above; our client (xivboot) starts it 1 above, so a cave ceiling 1-2 over the floor no longer
    /// reads as ground.
    /// </summary>
    public static class ClientProbe
    {
        /// <summary>The ray starts this far above the drawn y (xivboot; retail 2).</summary>
        public const float RayUp = 1.0f;
        /// <summary>And reaches this far below it (the chara's probe length; 5 only for the local player).</summary>
        public const float RayDown = 10.0f;

        /// <summary>
        /// Surfaces the probe can see. The chara's triangle filter drops (material &amp; 2) != 0 (water, sea
        /// planes, mat-2 cave ceilings), and the layer mask set up by RaptureWorld_initCollision minus layer 2
        /// leaves attribute kinds 1 and 16; kind 2 is the attr_col_* primitives.
        /// </summary>
        public static bool IsVisible(int material, int kind) => (material & 2) == 0 && (kind == 1 || kind == 16);
    }
}
