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

using Meteor.Map.Actors;
using Meteor.Map.AI;

namespace Meteor.Map.actors.chara.npc
{
    // A battle npc on the players' side: story allies, trusts, escorts.
    class Ally : BattleNpc
    {
        public Ally(int actorNumber, ActorClass actorClass, string uniqueId, Area spawnedArea, float posX, float posY, float posZ, float rot,
            ushort actorState, uint animationId, string customDisplayName)
            : base(actorNumber, actorClass, uniqueId, spawnedArea, posX, posY, posZ, rot, actorState, animationId, customDisplayName)
        {
            this.factionId = Factions.PlayerAlly;
            this.isAutoAttackEnabled = true;
            this.isMovingToSpawn = false;
        }

        public override string Kind => "ally";
    }
}
