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

namespace Meteor.Map.actors.chara.ai.utils
{
    // TP gained in battle. Only landed auto-attacks and damage taken give TP.
    static class TpGain
    {
        public const int MonsterSwing = 300;

        public static int PlayerSwing(double delaySeconds, int storeTp)
        {
            return (int)Math.Round(delaySeconds * 100 * (1 + storeTp * 0.001), MidpointRounding.AwayFromZero);
        }

        // A swing's TP is split across the weapon's own hits (fists hit twice); extra hits beyond
        // those add half a swing each.
        public static int ForHit(int swing, int hitNum, int baseHits)
        {
            baseHits = Math.Max(1, baseHits);
            hitNum = Math.Max(1, hitNum);
            if (hitNum <= baseHits)
                return swing * hitNum / baseHits - swing * (hitNum - 1) / baseHits;
            return (int)Math.Round(swing * 0.5, MidpointRounding.AwayFromZero);
        }

        public static double DamageTakenRate(bool monster, int level, int maxHp)
        {
            return monster ? 1600.0 / Math.Max(1, maxHp) : 4.5 * Math.Exp(-0.065 * level);
        }

        public static int FromDamageTaken(bool monster, int level, int maxHp, int damage)
        {
            return (int)Math.Ceiling(DamageTakenRate(monster, level, maxHp) * damage);
        }
    }
}
