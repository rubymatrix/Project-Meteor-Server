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
using Meteor.Map.actors.chara.npc;

namespace Meteor.Map.Actors
{
    // Monster body parts 1..8: body, right arm, left arm, legs, head, special right, special left,
    // special rear. Incapacitation is status 223019 + part. Part damage and breaking are in
    // Battle/Parts.lua; here a broken part disables the TP moves that need it, matched on the move's
    // name.
    static class PartBreak
    {
        public const uint INCAPACITATION_BASE = 223019;
        public const int PART_BODY = 1, PART_RIGHT_ARM = 2, PART_LEFT_ARM = 3, PART_LEGS = 4, PART_HEAD = 5,
                         PART_SPECIAL_RIGHT = 6, PART_SPECIAL_LEFT = 7, PART_SPECIAL_REAR = 8;

        private static int Bit(int part) { return 1 << (part - 1); }

        public static int IncapacitatedMask(BattleNpc mob)
        {
            int mask = 0;
            for (int part = PART_RIGHT_ARM; part <= PART_SPECIAL_REAR; part++)
                if (mob.statusEffects.HasStatusEffect(INCAPACITATION_BASE + (uint)part))
                    mask |= Bit(part);
            return mask;
        }

        public static int BrokenMask(BattleNpc mob)
        {
            return (int)mob.GetMobMod((uint)MobModifier.PartsBrokenMask);
        }

        // Arms means either arm; horns, wings and whiskers are the two special sides; tails and
        // stingers are the rear.
        public static int PartsOfSkill(BattleCommand skill)
        {
            string n = skill.name ?? "";
            int mask = 0;
            if (Has(n, "horn", "wing", "whisker", "feather", "tusk", "vine", "tendril", "branch", "bough"))
                mask |= Bit(PART_SPECIAL_RIGHT) | Bit(PART_SPECIAL_LEFT);
            if (Has(n, "tail", "sting", "stinger"))
                mask |= Bit(PART_SPECIAL_REAR);
            if (Has(n, "head", "bite", "fang", "maw", "jaw", "beak", "breath", "gaze", "glare", "stare", "eye",
                    "howl", "growl", "roar", "caw", "shriek", "bellow", "spit", "belch", "lap", "skull", "mandible", "sneeze"))
                mask |= Bit(PART_HEAD);
            if (Has(n, "claw", "swipe", "slash", "scythe", "punch", "cuff", "smash", "clap", "backhand", "pound", "blow", "fist"))
                mask |= Bit(PART_RIGHT_ARM) | Bit(PART_LEFT_ARM);
            if (Has(n, "kick", "stomp", "heel", "hoof", "charge", "stampede", "trample", "romp", "tumble", "somersault", "drop"))
                mask |= Bit(PART_LEGS);
            return mask;
        }

        private static bool Has(string name, params string[] words)
        {
            foreach (var w in words)
                if (name.IndexOf(w, StringComparison.OrdinalIgnoreCase) >= 0)
                    return true;
            return false;
        }

        // A move tied to both arms (or both specials) is lost when either one is incapacitated.
        public static bool IsSkillDisabled(BattleNpc mob, BattleCommand skill)
        {
            int incap = IncapacitatedMask(mob);
            return incap != 0 && (PartsOfSkill(skill) & incap) != 0;
        }

        // On respawn: part damage, the broken mask and the breakage byte start over.
        public static void Reset(BattleNpc mob)
        {
            for (uint m = (uint)MobModifier.PartDamage1; m <= (uint)MobModifier.PartDamage8; m++)
                mob.SetMobMod(m, 0);
            mob.SetMobMod((uint)MobModifier.PartsBrokenMask, 0);
            if (mob.GetSubState().breakage != 0)
            {
                mob.GetSubState().breakage = 0;
                mob.SubstateModified();
            }
        }
    }
}
