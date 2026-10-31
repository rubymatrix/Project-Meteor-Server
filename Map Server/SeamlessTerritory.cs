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
using Meteor.Map.DataObjects;

namespace Meteor.Map
{
    enum SeamlessAction
    {
        None,
        ChangeZone,
        Merge,
        ClearMerge,
    }

    struct SeamlessDecision
    {
        public SeamlessAction action;
        public uint zoneId;
        public string reason;

        public SeamlessDecision(SeamlessAction action, uint zoneId, string reason)
        {
            this.action = action;
            this.zoneId = zoneId;
            this.reason = reason;
        }
    }

    // Which zone of a seamless region a position is in. Corridor boxes alone miss a player who walks
    // around the merge box, so a position first goes to a territory: between city halves, the half
    // with the nearest spawns (a switch needs HYSTERESIS and CLAIM_RADIUS); city and field, only near
    // the corridor. Then corridors merge or change zone, and SHARE_MARGIN keeps the seam merged.
    class SeamlessMap
    {
        public const float HYSTERESIS = 5.0f;
        public const float CLAIM_RADIUS = 80.0f;
        public const float SHARE_MARGIN = 30.0f;

        private readonly Dictionary<uint, List<SeamlessBoundry>> rowsByRegion = new Dictionary<uint, List<SeamlessBoundry>>();
        private readonly Dictionary<uint, List<SeamlessBox>> boxesByZone = new Dictionary<uint, List<SeamlessBox>>();
        private readonly Dictionary<uint, List<float>> anchorsByZone = new Dictionary<uint, List<float>>(); // x,y,z triples
        private readonly HashSet<uint> townZones = new HashSet<uint>();

        public void AddRow(SeamlessBoundry row)
        {
            List<SeamlessBoundry> rows;
            if (!rowsByRegion.TryGetValue(row.regionId, out rows))
                rowsByRegion[row.regionId] = rows = new List<SeamlessBoundry>();
            rows.Add(row);
            GetOrAdd(boxesByZone, row.zoneId1).Add(row.zone1);
            GetOrAdd(boxesByZone, row.zoneId2).Add(row.zone2);
        }

        public void SetTown(uint zoneId, bool isTown)
        {
            if (isTown)
                townZones.Add(zoneId);
            else
                townZones.Remove(zoneId);
        }

        public void AddAnchor(uint zoneId, float x, float y, float z)
        {
            if (!IsFinite(x) || !IsFinite(y) || !IsFinite(z) || (Math.Abs(x) < 0.01f && Math.Abs(z) < 0.01f))
                return; // unplaced rows sit at the origin
            List<float> anchors = GetOrAdd(anchorsByZone, zoneId);
            anchors.Add(x);
            anchors.Add(y);
            anchors.Add(z);
        }

        public bool HasRegion(uint regionId)
        {
            return rowsByRegion.ContainsKey(regionId);
        }

        public bool IsSplitCity(uint zoneA, uint zoneB)
        {
            return townZones.Contains(zoneA) && townZones.Contains(zoneB);
        }

        // Spawns count height because city halves stack in places (Ul'dah's Wellhead Lift). The boxes
        // are X/Z only. A NaN y measures in X/Z only.
        public float TerritoryDistance(uint zoneId, float x, float y, float z)
        {
            float best = float.MaxValue;
            List<SeamlessBox> boxes;
            if (boxesByZone.TryGetValue(zoneId, out boxes))
                foreach (SeamlessBox box in boxes)
                    best = Math.Min(best, box.Distance(x, z));
            List<float> anchors;
            if (anchorsByZone.TryGetValue(zoneId, out anchors))
            {
                float bestSq = best == float.MaxValue ? float.MaxValue : best * best;
                bool useY = !float.IsNaN(y);
                for (int i = 0; i < anchors.Count; i += 3)
                {
                    float dx = anchors[i] - x, dz = anchors[i + 2] - z;
                    float dy = useY ? anchors[i + 1] - y : 0.0f;
                    float dSq = dx * dx + dy * dy + dz * dz;
                    if (dSq < bestSq)
                        bestSq = dSq;
                }
                best = (float)Math.Sqrt(bestSq);
            }
            return best;
        }

        public uint TerritoryOwner(uint regionId, uint zoneId, float x, float y, float z, out uint shareZoneId)
        {
            shareZoneId = 0;
            List<SeamlessBoundry> rows;
            if (!IsFinite(x) || !IsFinite(z) || !rowsByRegion.TryGetValue(regionId, out rows))
                return zoneId;

            uint owner = zoneId;
            float ownerMargin = 0.0f;
            float bestShare = float.MaxValue;
            float ownDistance = -1.0f;

            foreach (SeamlessBoundry row in rows)
            {
                if (row.zoneId1 != zoneId && row.zoneId2 != zoneId)
                    continue;
                bool inZone1 = row.zoneId1 == zoneId;
                uint other = inZone1 ? row.zoneId2 : row.zoneId1;

                float dOwn, dOther;
                if (IsSplitCity(zoneId, other))
                {
                    if (ownDistance < 0.0f)
                        ownDistance = TerritoryDistance(zoneId, x, y, z);
                    dOwn = ownDistance;
                    dOther = TerritoryDistance(other, x, y, z);
                    if (dOther > CLAIM_RADIUS)
                        continue;
                    if (dOther - dOwn <= SHARE_MARGIN && dOther < bestShare)
                    {
                        bestShare = dOther;
                        shareZoneId = other;
                    }
                }
                else
                {
                    if (!row.IsNear(x, z, x, z))
                        continue;
                    dOwn = (inZone1 ? row.zone1 : row.zone2).Distance(x, z);
                    dOther = (inZone1 ? row.zone2 : row.zone1).Distance(x, z);
                }

                float margin = dOwn - dOther;
                if (margin > HYSTERESIS && margin > ownerMargin)
                {
                    owner = other;
                    ownerMargin = margin;
                }
            }

            if (owner != zoneId)
                shareZoneId = 0;
            return owner;
        }

        // mergedId 0 = nothing merged. A zero-length segment re-checks a standing position (zone-in).
        public SeamlessDecision Decide(uint regionId, uint zoneId, uint mergedId, float fromX, float fromZ, float toX, float toY, float toZ)
        {
            List<SeamlessBoundry> rows;
            if (!rowsByRegion.TryGetValue(regionId, out rows))
                return Clear(mergedId);

            uint shareZoneId;
            uint owner = TerritoryOwner(regionId, zoneId, toX, toY, toZ, out shareZoneId);
            if (owner != zoneId)
                return new SeamlessDecision(SeamlessAction.ChangeZone, owner, "territory");

            foreach (SeamlessBoundry bounds in rows)
            {
                if (zoneId != bounds.zoneId1 && zoneId != bounds.zoneId2)
                    continue;
                if (!bounds.IsNear(fromX, fromZ, toX, toZ))
                    continue;

                bool inZone1 = zoneId == bounds.zoneId1;
                SeamlessBox own = inZone1 ? bounds.zone1 : bounds.zone2;
                SeamlessBox destination = inZone1 ? bounds.zone2 : bounds.zone1;
                uint destinationId = inZone1 ? bounds.zoneId2 : bounds.zoneId1;

                if (own.Contains(toX, toZ))
                    break;

                if (SeamlessBoundaryPolicy.ReachedDestination(destination, bounds.merge, mergedId == destinationId, fromX, fromZ, toX, toZ))
                    return new SeamlessDecision(SeamlessAction.ChangeZone, destinationId, "corridor");

                if (bounds.merge.Contains(toX, toZ) || bounds.merge.Intersects(fromX, fromZ, toX, toZ))
                    return Merge(mergedId, destinationId);

                if (mergedId == destinationId && SeamlessBoundaryPolicy.InCorridor(destination, bounds.merge, toX, toZ))
                    return new SeamlessDecision(SeamlessAction.None, 0, null);
            }

            if (shareZoneId != 0)
                return Merge(mergedId, shareZoneId);
            return Clear(mergedId);
        }

        private static SeamlessDecision Merge(uint mergedId, uint zoneId)
        {
            if (mergedId == zoneId)
                return new SeamlessDecision(SeamlessAction.None, 0, null);
            return new SeamlessDecision(SeamlessAction.Merge, zoneId, null);
        }

        private static SeamlessDecision Clear(uint mergedId)
        {
            return new SeamlessDecision(mergedId == 0 ? SeamlessAction.None : SeamlessAction.ClearMerge, 0, null);
        }

        private static List<T> GetOrAdd<T>(Dictionary<uint, List<T>> map, uint key)
        {
            List<T> list;
            if (!map.TryGetValue(key, out list))
                map[key] = list = new List<T>();
            return list;
        }

        private static bool IsFinite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}
