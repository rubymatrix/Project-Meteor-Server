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

namespace Meteor.Map.actors.chara.npc
{
    // Per-mob numbers kept in the battle npc modifier tables. Behavior (senses, leash, roaming,
    // linking, scripts) is in AI profiles (Data/scripts/Ai).
    enum MobModifier
    {
        None              = 0,
        ExpBonus          = 10,
        HpScale           = 13,
        CallForHelp       = 22, // actor with this id outside of target's party with this can attack me
        FreeForAll        = 23, // any actor can attack me
        Linked            = 26, // Did I get aggroed via linking?
        LinkCount         = 27, // How many BattleNPCs got linked with me
        // Body parts: damage toward the next break per part, and parts broken since spawn (bit part-1).
        PartDamage1       = 61,
        PartDamage8       = 68,
        PartsBrokenMask   = 69
    }
}
