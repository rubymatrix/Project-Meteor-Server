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

using MySql.Data.MySqlClient;

namespace Meteor.Map.DataObjects
{
    class PassiveGuildleveData
    {
        public readonly uint id;
        public readonly uint plateId;
        public readonly uint borderId;
        public readonly uint recommendedClass;
        public readonly uint issuingLocation;
        public readonly uint leveLocation;
        public readonly uint deliveryDisplayName;

        public readonly int[] objectiveItemId;
        public readonly int[] objectiveQuantity;
        public readonly int[] rewardItemId;
        public readonly int[] rewardQuantity;
        public readonly int[] numberOfAttempts;
        public readonly int[] recommendedLevel;

        public PassiveGuildleveData(MySqlDataReader reader)
        {
            id = reader.GetUInt32("id");
            plateId = reader.GetUInt32("plateId");
            borderId = reader.GetUInt32("borderId");
            recommendedClass = reader.GetUInt32("recommendedClass");
            issuingLocation = reader.GetUInt32("issuingLocation");
            leveLocation = reader.GetUInt32("guildleveLocation");
            deliveryDisplayName = reader.GetUInt32("deliveryDisplayName");
            
            objectiveItemId = new int[4];
            objectiveQuantity = new int[4];
            rewardItemId = new int[4];
            rewardQuantity = new int[4];
            numberOfAttempts = new int[4];
            recommendedLevel = new int[4];

            objectiveItemId[0] = reader.GetInt32("objectiveItemId1");
            objectiveItemId[1] = reader.GetInt32("objectiveItemId2");
            objectiveItemId[2] = reader.GetInt32("objectiveItemId3");
            objectiveItemId[3] = reader.GetInt32("objectiveItemId4");

            objectiveQuantity[0] = reader.GetInt32("objectiveQuantity1");
            objectiveQuantity[1] = reader.GetInt32("objectiveQuantity2");
            objectiveQuantity[2] = reader.GetInt32("objectiveQuantity3");
            objectiveQuantity[3] = reader.GetInt32("objectiveQuantity4");

            rewardItemId[0] = reader.GetInt32("rewardItemId1");
            rewardItemId[1] = reader.GetInt32("rewardItemId2");
            rewardItemId[2] = reader.GetInt32("rewardItemId3");
            rewardItemId[3] = reader.GetInt32("rewardItemId4");

            rewardQuantity[0] = reader.GetInt32("rewardQuantity1");
            rewardQuantity[1] = reader.GetInt32("rewardQuantity2");
            rewardQuantity[2] = reader.GetInt32("rewardQuantity3");
            rewardQuantity[3] = reader.GetInt32("rewardQuantity4");

            numberOfAttempts[0] = reader.GetInt32("numberOfAttempts1");
            numberOfAttempts[1] = reader.GetInt32("numberOfAttempts2");
            numberOfAttempts[2] = reader.GetInt32("numberOfAttempts3");
            numberOfAttempts[3] = reader.GetInt32("numberOfAttempts4");

            recommendedLevel[0] = reader.GetInt32("recommendedLevel1");
            recommendedLevel[1] = reader.GetInt32("recommendedLevel2");
            recommendedLevel[2] = reader.GetInt32("recommendedLevel3");
            recommendedLevel[3] = reader.GetInt32("recommendedLevel4");
        }

    }
}
