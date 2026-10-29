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
using System.Linq;
using Meteor.Map.Actors;
using Meteor.Map.Scripting;

namespace Meteor.Map.actors.chara.ai
{
    enum HateMode
    {
        Normal,     // the most enmity is the target
        Locked,     // only listed tags or actors gain hate
        Weighted,   // tag weights multiply enmity
        Fixed,      // the script picks the target
    }

    class HateEntry
    {
        public Character actor;
        public uint cumulativeEnmity;
        public uint volatileEnmity;
        public bool isActive;

        public HateEntry(Character actor, uint cumulativeEnmity = 0, uint volatileEnmity = 0, bool isActive = false)
        {
            this.actor = actor;
            this.cumulativeEnmity = cumulativeEnmity;
            this.volatileEnmity = volatileEnmity;
            this.isActive = isActive;
        }
    }

    class HateContainer
    {
        private readonly Dictionary<Character, HateEntry> hateList = new Dictionary<Character, HateEntry>();
        private readonly Character owner;
        private readonly HashSet<string> lockedTags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private readonly HashSet<Character> lockedActors = new HashSet<Character>();
        private readonly Dictionary<string, float> weights = new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase);
        private Character fixedTarget;
        private long fixedUntil;

        public HateMode Mode { get; private set; } = HateMode.Normal;

        public HateContainer(Character owner)
        {
            this.owner = owner;
        }

        // mode: normal | locked | weighted | fixed; opts.tags: a list (locked) or a tag = weight map.
        public void SetMode(string mode, ScriptParams opts)
        {
            Mode = Enum.TryParse<HateMode>(mode ?? "normal", true, out var m) ? m : HateMode.Normal;
            lockedTags.Clear();
            lockedActors.Clear();
            weights.Clear();
            var tags = opts?.Table("tags");
            if (tags != null)
            {
                foreach (var v in tags.List)
                    if (v is string s)
                        lockedTags.Add(s);
                foreach (var k in tags.Keys)
                    weights[k] = tags.Float(k, 1);
            }
            var actors = opts?.Table("actors");
            if (actors != null)
                foreach (var v in actors.List)
                    if (v is Character c)
                        lockedActors.Add(c);
        }

        public void SetModeFrom(string mode, XLua.LuaTable opts) => SetMode(mode, ScriptParams.From(opts));

        public bool Allows(Character target)
        {
            if (Mode != HateMode.Locked)
                return true;
            if (lockedActors.Contains(target))
                return true;
            foreach (var t in lockedTags)
                if (target.HasTag(t))
                    return true;
            return false;
        }

        public void AddBaseHate(Character target)
        {
            if (target == null || target == owner || !Allows(target) || HasHateForTarget(target))
                return;
            hateList.Add(target, new HateEntry(target, 1, 0, true));
            if (owner is BattleNpc bnpc)
                bnpc.OnHateAdded(target);
        }

        // Hate from a linked pull: the mob fights but stays unclaimed (orange) until it is hit.
        // enmity seeds the entry without claiming it.
        public void AddLinkHate(Character target, uint enmity = 0)
        {
            if (!HasHateForTarget(target))
            {
                hateList.Add(target, new HateEntry(target, 1, 0, true));

                if (owner is BattleNpc bnpc)
                    bnpc.OnLinkHateAdded();
            }
            if (enmity > 0 && hateList.TryGetValue(target, out var entry))
                entry.cumulativeEnmity = Math.Max(entry.cumulativeEnmity, enmity);
        }

        public void UpdateHate(Character target, int damage)
        {
            if (HasHateForTarget(target) && damage > 0 && owner is BattleNpc bnpc)
                bnpc.OnHateAdded(target);
            AddBaseHate(target);
            if (hateList.TryGetValue(target, out var entry))
                entry.cumulativeEnmity += (uint)Math.Max(0, damage);
        }

        public void ClearHate(Character target = null)
        {
            if (target != null)
                hateList.Remove(target);
            else
                hateList.Clear();
            if (fixedTarget != null && (target == null || target == fixedTarget))
                fixedTarget = null;
            if (hateList.Count == 0 && owner is BattleNpc bnpc)
                bnpc.OnHateListEmptied();
        }

        public Dictionary<Character, HateEntry> GetHateList()
        {
            return hateList;
        }

        public bool HasHateForTarget(Character target)
        {
            return target != null && hateList.ContainsKey(target);
        }

        // Drops entries for actors that died, left the area or are no longer valid foes.
        public void Prune(Character self)
        {
            foreach (var c in hateList.Keys.ToList())
                if (c.IsDead() || c.CurrentArea != self.CurrentArea || !Allows(c))
                    ClearHate(c);
        }

        public void Fixate(Character target, double seconds)
        {
            fixedTarget = target;
            fixedUntil = seconds > 0 ? GameClock.NowMs + (long)(seconds * 1000) : long.MaxValue;
            AddBaseHate(target);
        }

        public Character GetMostHatedTarget()
        {
            double best = 0;
            Character target = null;
            foreach (var entry in hateList.Values)
            {
                if (!entry.isActive)
                    continue;
                double score = entry.cumulativeEnmity;
                if (Mode == HateMode.Weighted)
                    foreach (var w in weights)
                        if (entry.actor.HasTag(w.Key))
                            score *= w.Value;
                if (score > best)
                {
                    best = score;
                    target = entry.actor;
                }
            }
            return target;
        }

        public Character GetTarget()
        {
            if (fixedTarget != null && (GameClock.NowMs > fixedUntil || fixedTarget.IsDead()))
                fixedTarget = null;
            return fixedTarget ?? GetMostHatedTarget();
        }

        public List<object> Describe()
        {
            return hateList.Values.Select(e => (object)new { actor = e.actor.GetName() + "#" + e.actor.Id, enmity = e.cumulativeEnmity }).ToList();
        }
    }
}
