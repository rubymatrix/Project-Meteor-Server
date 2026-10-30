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

using Meteor.Map.packets.send.actor;

namespace Meteor.Map.Actors
{
    partial class Player
    {
        // Joins company 1-3 (Maelstrom, Twin Adder, Immortal Flames) at rank, or leaves with 0. The
        // other companies' ranks are cleared, as the client warns when a recruit joins officially.
        public void SetGrandCompany(byte company, byte rank)
        {
            if (company > 3)
                return;
            gcCurrent = company;
            gcRankLimsa = company == 1 ? rank : (byte)0;
            gcRankGridania = company == 2 ? rank : (byte)0;
            gcRankUldah = company == 3 ? rank : (byte)0;
            Database.SavePlayerGrandCompany(this);
            QueuePacket(SetGrandCompanyPacket.BuildPacket(Id, gcCurrent, gcRankLimsa, gcRankGridania, gcRankUldah));
            // Grand Company quests are offered by company.
            questStateManager.UpdateQuestAbandoned();
        }
    }
}
