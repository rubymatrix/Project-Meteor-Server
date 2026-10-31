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

namespace Meteor.Map
{
    // X/Z box tests for server_seamless_zonechange_bounds. Corners may be stored in either order.
    static class SeamlessBoundaryPolicy
    {
        public static bool ContainsPoint(float x, float z, float x1, float z1, float x2, float z2)
        {
            if (!IsFinite(x) || !IsFinite(z))
                return false;

            return Math.Min(x1, x2) <= x && x <= Math.Max(x1, x2)
                && Math.Min(z1, z2) <= z && z <= Math.Max(z1, z2);
        }

        // Position updates are samples, so a narrow box can sit between two of them: test the whole
        // movement segment, not just its end.
        public static bool SegmentIntersects(float fromX, float fromZ, float toX, float toZ, float x1, float z1, float x2, float z2)
        {
            if (!IsFinite(fromX) || !IsFinite(fromZ) || !IsFinite(toX) || !IsFinite(toZ))
                return false;

            float tMin = 0.0f, tMax = 1.0f;
            return ClipAxis(fromX, toX - fromX, Math.Min(x1, x2), Math.Max(x1, x2), ref tMin, ref tMax)
                && ClipAxis(fromZ, toZ - fromZ, Math.Min(z1, z2), Math.Max(z1, z2), ref tMin, ref tMax);
        }

        // Passing through the destination box only counts once merged, or if the same segment also
        // crossed the merge box, so a long sample can't skip the corridor from the wrong side.
        public static bool ReachedDestination(SeamlessBox destination, SeamlessBox merge, bool alreadyMerged,
                                              float fromX, float fromZ, float toX, float toZ)
        {
            if (destination.Contains(toX, toZ))
                return true;
            if (!destination.Intersects(fromX, fromZ, toX, toZ))
                return false;
            return alreadyMerged || merge.Intersects(fromX, fromZ, toX, toZ);
        }

        // The rows leave gaps between the merge and destination boxes; keep the merged zone anywhere
        // in their bounding rectangle instead of dropping it in a gap.
        public static bool InCorridor(SeamlessBox destination, SeamlessBox merge, float x, float z)
        {
            return ContainsPoint(x, z,
                Math.Min(destination.minX, merge.minX), Math.Min(destination.minZ, merge.minZ),
                Math.Max(destination.maxX, merge.maxX), Math.Max(destination.maxZ, merge.maxZ));
        }

        private static bool ClipAxis(float start, float delta, float min, float max, ref float tMin, ref float tMax)
        {
            if (delta == 0.0f)
                return min <= start && start <= max;

            float enter = (min - start) / delta;
            float exit = (max - start) / delta;
            if (enter > exit)
            {
                float swap = enter;
                enter = exit;
                exit = swap;
            }

            tMin = Math.Max(tMin, enter);
            tMax = Math.Min(tMax, exit);
            return tMin <= tMax;
        }

        private static bool IsFinite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }

    // Some rows store corners high-to-low, so nothing compares the raw columns directly.
    struct SeamlessBox
    {
        public readonly float minX, minZ, maxX, maxZ;

        public SeamlessBox(float x1, float z1, float x2, float z2)
        {
            minX = Math.Min(x1, x2);
            maxX = Math.Max(x1, x2);
            minZ = Math.Min(z1, z2);
            maxZ = Math.Max(z1, z2);
        }

        public bool Contains(float x, float z)
        {
            return SeamlessBoundaryPolicy.ContainsPoint(x, z, minX, minZ, maxX, maxZ);
        }

        public bool Intersects(float fromX, float fromZ, float toX, float toZ)
        {
            return SeamlessBoundaryPolicy.SegmentIntersects(fromX, fromZ, toX, toZ, minX, minZ, maxX, maxZ);
        }

        public float Distance(float x, float z)
        {
            float dx = Math.Max(0.0f, Math.Max(minX - x, x - maxX));
            float dz = Math.Max(0.0f, Math.Max(minZ - z, z - maxZ));
            return (float)Math.Sqrt(dx * dx + dz * dz);
        }

        public bool Near(float x, float z, float margin)
        {
            return x >= minX - margin && x <= maxX + margin && z >= minZ - margin && z <= maxZ + margin;
        }
    }

    // Area bookkeeping for a seam crossing (WorldManager.MoveAcrossSeam). An area that still lists the
    // actor afterwards keeps the entry it has, so a player watching from there never sees the actor
    // despawn and respawn.
    struct SeamCrossing<T> where T : class
    {
        public bool removeFromOld;
        public T dropMerged;
        public T addMerged;
        public T merged;

        public static SeamCrossing<T> Plan(T old, T merged, T destination, T keep)
        {
            if (keep == destination)
                keep = null;
            return new SeamCrossing<T>
            {
                removeFromOld = old != null && old != keep,
                dropMerged = merged != null && merged != destination && merged != keep ? merged : null,
                addMerged = keep != null && keep != old && keep != merged ? keep : null,
                merged = keep,
            };
        }
    }
}
