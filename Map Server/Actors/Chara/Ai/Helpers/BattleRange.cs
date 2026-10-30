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

namespace Meteor.Map.actors.chara.ai
{
    // Battle range and melee spacing measured to the target's body surface (Character.GetBodyRadius),
    // as the client spaces melee: its attack approach works on dist - r_self - r_target.
    static class BattleRange
    {
        // Surface-to-surface gap a chasing melee stops at.
        public const float MELEE_GAP = 0.5f;

        // A chaser stops at least this far inside its reach, so the swing is legal from where it stands.
        public const float REACH_MARGIN = 0.5f;

        // Added to area-query radii so a big body whose centre is outside the range but whose surface is
        // inside still counts. Above the largest spawned radius.
        public const float BROADPHASE_PAD = 6.0f;

        // Negative inside the body.
        public static float SurfaceDistance(float centreDistance, float targetRadius) =>
            centreDistance - Math.Max(0.0f, targetRadius);

        public static bool InReach(float centreDistance, float targetRadius, float range, float leeway = 0.0f) =>
            SurfaceDistance(centreDistance, targetRadius) <= range + leeway;

        public static bool TooClose(float centreDistance, float targetRadius, float minRange) =>
            minRange > 0 && SurfaceDistance(centreDistance, targetRadius) < minRange;

        // A circle or ring touches the target's body: dist - r <= max and dist + r >= min.
        public static bool InArea(float centreDistance, float targetRadius, float maxRadius, float minRadius)
        {
            float r = Math.Max(0.0f, targetRadius);
            return centreDistance - r <= maxRadius && centreDistance + r >= minRadius;
        }

        // Centre-to-centre distance a melee chaser stops at, capped so the target's surface stays within
        // attackRange - REACH_MARGIN. An override replaces the spacing but not the cap.
        public static float StopDistance(float selfRadius, float targetRadius, float attackRange, float overrideDistance = 0.0f)
        {
            float rs = Math.Max(0.0f, selfRadius), rt = Math.Max(0.0f, targetRadius);
            float want = overrideDistance > 0 ? overrideDistance : rs + rt + MELEE_GAP;
            float cap = rt + attackRange - REACH_MARGIN;
            return Math.Max(0.0f, Math.Min(want, cap));
        }
    }
}
