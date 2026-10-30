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
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.group;
using Meteor.Map.packets.send.actor.battle;

namespace Meteor.Map.Actors
{
    // Party-size bonus: a light party (4 to 7 members) gives each member Comradery, a full party of
    // 8 gives Strength in Numbers. Only members within 5 levels above or 10 below count. The stat
    // part is Battle/Partybonus.lua; the gain and loss lines are the statuses' own texts.
    partial class Player
    {
        public const int LIGHT_PARTY_MIN_MEMBERS = 4;
        public const int FULL_PARTY_MEMBERS = 8;
        public const int PARTY_BONUS_LEVELS_ABOVE = 5;
        public const int PARTY_BONUS_LEVELS_BELOW = 10;
        private const double PARTY_BONUS_CHECK_SECONDS = 1.0;

        private DateTime nextPartyBonusCheck = DateTime.MinValue;

        public uint GetWantedPartyBonus()
        {
            Party party = currentParty as Party;
            int size = party != null ? CountPartyBonusMembers(party) : 1;
            if (size >= FULL_PARTY_MEMBERS)
                return (uint)StatusEffectId.StrengthinNumbers;
            if (size >= LIGHT_PARTY_MIN_MEMBERS)
                return (uint)StatusEffectId.Comradery;
            return 0;
        }

        // Self included; members the map can't find (offline) don't count.
        public int CountPartyBonusMembers(Party party)
        {
            int myLevel = GetLevel();
            int count = 0;
            foreach (uint memberId in party.members)
            {
                Character member = memberId == Id ? this : Server.GetWorldManager().GetActorInWorld(memberId) as Character;
                if (member == null)
                    continue;
                int diff = member.GetLevel() - myLevel;
                if (diff >= -PARTY_BONUS_LEVELS_BELOW && diff <= PARTY_BONUS_LEVELS_ABOVE)
                    count++;
            }
            return Math.Max(1, count);
        }

        private void UpdatePartyBonus(DateTime tick)
        {
            if (tick < nextPartyBonusCheck)
                return;
            nextPartyBonusCheck = tick.AddSeconds(PARTY_BONUS_CHECK_SECONDS);

            // The client isn't ready for status packets while it loads into an area.
            if (CurrentArea == null || isZoneChanging || playerSession == null || playerSession.isUpdatesLocked)
                return;

            uint want = GetWantedPartyBonus();
            CommandResultContainer results = new CommandResultContainer();
            bool changed = false;

            foreach (uint id in new uint[] { (uint)StatusEffectId.Comradery, (uint)StatusEffectId.StrengthinNumbers })
            {
                if (id == want)
                    continue;
                StatusEffect have = statusEffects.GetStatusEffectById(id);
                if (have != null)
                    changed |= statusEffects.RemoveStatusEffect(have, results, have.GetStatusLossTextId(), false);
            }

            if (want != 0 && !statusEffects.HasStatusEffect(want))
            {
                StatusEffect effect = Server.GetWorldManager().GetStatusEffect(want);
                if (effect != null)
                {
                    effect.SetDuration(UInt32.MaxValue);
                    changed |= statusEffects.AddStatusEffect(effect, this, results, effect.GetStatusGainTextId());
                }
            }

            if (changed)
            {
                results.CombineLists();
                DoBattleAction(0, 0x7c000062, results.GetList());
            }
        }
    }
}
