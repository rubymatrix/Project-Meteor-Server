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

namespace Meteor.Map.DataObjects
{
    // One row of server_seamless_zonechange_bounds. The "y" columns are world Z.
    class SeamlessBoundry
    {
        private const float NEAR_MARGIN = 20.0f;

        public readonly uint regionId;
        public readonly uint zoneId1, zoneId2;
        public readonly SeamlessBox zone1, zone2, merge;
        private readonly SeamlessBox outer;

        public SeamlessBoundry(uint regionId, uint zoneId1, uint zoneId2, float zone1_x1, float zone1_y1, float zone1_x2, float zone1_y2, float zone2_x1, float zone2_y1, float zone2_x2, float zone2_y2, float merge_x1, float merge_y1, float merge_x2, float merge_y2)
        {
            this.regionId = regionId;
            this.zoneId1 = zoneId1;
            this.zoneId2 = zoneId2;
            zone1 = new SeamlessBox(zone1_x1, zone1_y1, zone1_x2, zone1_y2);
            zone2 = new SeamlessBox(zone2_x1, zone2_y1, zone2_x2, zone2_y2);
            merge = new SeamlessBox(merge_x1, merge_y1, merge_x2, merge_y2);
            outer = new SeamlessBox(
                System.Math.Min(zone1.minX, System.Math.Min(zone2.minX, merge.minX)),
                System.Math.Min(zone1.minZ, System.Math.Min(zone2.minZ, merge.minZ)),
                System.Math.Max(zone1.maxX, System.Math.Max(zone2.maxX, merge.maxX)),
                System.Math.Max(zone1.maxZ, System.Math.Max(zone2.maxZ, merge.maxZ)));
        }

        public bool IsNear(float fromX, float fromZ, float toX, float toZ)
        {
            return outer.Near(toX, toZ, NEAR_MARGIN) || outer.Near(fromX, fromZ, NEAR_MARGIN);
        }
    }
}
