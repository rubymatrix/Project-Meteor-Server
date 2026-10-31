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
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.packets.send.actor;
using Meteor.Map.Scripting;
using Meteor.Map.utils;

namespace Meteor.Map.AI
{
    // What a character notices. Configured by its profile; the Detect, Guard and Assist behaviors
    // use it.
    class Perception
    {
        public float SightRange = 0, SightCone = 120;
        public float SoundRange = 0;
        public float MagicRange = 0;
        public float LowHpRange = 0, LowHpPercent = 75;
        public float ProximityRange = 0;
        public int LevelGap = 10;
        public float VerticalLimit = 8;
        public string FilterTag;
        public int FilterFaction = -1;
        public ScriptCallback FilterFn;

        private readonly Character owner;

        public Perception(Character owner)
        {
            this.owner = owner;
        }

        public bool Senses => SightRange > 0 || SoundRange > 0 || MagicRange > 0 || LowHpRange > 0 || ProximityRange > 0;

        public float MaxRange => Math.Max(Math.Max(SightRange, SoundRange), Math.Max(Math.Max(MagicRange, LowHpRange), ProximityRange));

        // The old pool detection flags, for spawns with no senses in their profile.
        public void FromDetectionType(DetectionType type)
        {
            if ((type & DetectionType.Sight) != 0) SightRange = 20;
            if ((type & DetectionType.Sound) != 0) SoundRange = 8;
            if ((type & DetectionType.Magic) != 0) MagicRange = 20;
            if ((type & DetectionType.LowHp) != 0) LowHpRange = 20;
            if ((type & DetectionType.IgnoreLevelDifference) != 0) LevelGap = 0;
        }

        public void ConfigureFrom(XLua.LuaTable t) => Configure(ScriptParams.From(t));

        public void Configure(ScriptParams p)
        {
            if (p == null)
                return;
            SightRange = Sense(p, "sight", "range", SightRange);
            SightCone = Sense(p, "sight", "cone", SightCone);
            SoundRange = Sense(p, "sound", "range", SoundRange);
            MagicRange = Sense(p, "magic", "range", MagicRange);
            LowHpRange = Sense(p, "lowHp", "range", LowHpRange);
            LowHpPercent = Sense(p, "lowHp", "below", LowHpPercent);
            ProximityRange = Sense(p, "proximity", "range", ProximityRange);
            if (p.Has("levelGap"))
                LevelGap = p.Get("levelGap") is bool b && !b ? 0 : p.Int("levelGap", LevelGap);
            var filter = p.Table("filter");
            if (filter != null)
            {
                FilterTag = filter.String("tag");
                FilterFaction = Factions.Id(filter.String("faction"));
                FilterFn = filter.Callback("fn");
            }
        }

        private static float Sense(ScriptParams p, string sense, string field, float current)
        {
            var v = p.Get(sense);
            if (v is bool b)
                return b ? current : 0;
            if (v is double d && field == "range")
                return (float)d;
            if (v is ScriptParams t && t.Has(field))
                return t.Float(field, current);
            return current;
        }

        public bool PassesFilter(Character target)
        {
            if (FilterTag != null && !target.HasTag(FilterTag))
                return false;
            if (FilterFaction >= 0 && target.factionId != FilterFaction)
                return false;
            if (FilterFn != null && !FilterFn.Test(owner, target))
                return false;
            return true;
        }

        // Whether owner would aggro target now.
        public bool Detects(Character target)
        {
            if (target == null || target == owner || target.IsDead() || owner.IsDead())
                return false;
            if (target.currentMainState == SetActorStatePacket.MAIN_STATE_MOUNTED)
                return false;
            if (!Factions.IsHostile(owner, target) || !PassesFilter(target))
                return false;
            // A leve's monsters only notice that leve's participants.
            if (owner is BattleNpc bnpc && bnpc.leveDirector != null && target is Player && !bnpc.leveDirector.IsParticipant(target))
                return false;
            if (LevelGap > 0 && target.GetLevel() - owner.GetLevel() > LevelGap)
                return false;
            if (Math.Abs(target.positionY - owner.positionY) > VerticalLimit)
                return false;

            float distance = Utils.Distance(owner.GetPosAsVector3(), target.GetPosAsVector3());
            if (distance > MaxRange)
                return false;
            bool sneaking = target.GetMod(Modifier.Stealth) > 0;

            bool sensed = (ProximityRange > 0 && distance <= ProximityRange)
                || (SightRange > 0 && !sneaking && distance <= SightRange && owner.IsFacing(target, SightCone / 2))
                || (SoundRange > 0 && !sneaking && distance <= SoundRange)
                || (MagicRange > 0 && distance <= MagicRange && target.aiContainer.IsCurrentState<MagicState>())
                || (LowHpRange > 0 && distance <= LowHpRange && target.GetHPP() < LowHpPercent);
            return sensed && CanSee(target);
        }

        public bool CanSee(Actor target)
        {
            return owner.CurrentArea == null || NavmeshUtils.CanSee(owner.CurrentArea, owner.positionX, owner.positionY, owner.positionZ,
                target.positionX, target.positionY, target.positionZ);
        }

        public List<Character> Candidates(float range)
        {
            var list = new List<Character>();
            if (owner.CurrentArea == null)
                return list;
            foreach (var c in owner.CurrentArea.GetActorsAroundActor<Character>(owner, (int)Math.Ceiling(Math.Max(range, 1))))
                if (c != owner && c.IsAlive())
                    list.Add(c);
            return list;
        }
    }
}
