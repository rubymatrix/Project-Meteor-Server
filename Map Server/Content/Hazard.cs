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
using Meteor.Map.AI;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.Scripting;

namespace Meteor.Map.Content
{
    // A telegraphed area that goes off at a set time. Allies step out of it (Avoid); when it goes
    // off it hits whoever is inside and raises HazardResolved.
    class Hazard
    {
        private static int nextId;

        public readonly int Id = ++nextId;
        public string Name;
        public Shape Shape;
        public Character Source;
        public long GoesOffAt;
        public long LingerUntil;
        public int Damage;
        public float DamagePercent;
        public uint Animation;
        public ushort Command;
        public string Hits = "foes";         // foes | all | players
        public ScriptCallback OnResolve;
        public bool Resolved;

        public static Hazard From(ScriptParams p, Character defaultSource)
        {
            var h = new Hazard
            {
                Name = p.String("name"),
                Shape = Shape.From(p),
                Source = p.Get("source") as Character ?? defaultSource,
                GoesOffAt = GameClock.NowMs + (long)(p.Float("delay", 0) * 1000),
                Damage = p.Int("damage"),
                DamagePercent = p.Float("percent"),
                Animation = (uint)p.Int("animation"),
                Command = (ushort)p.Int("command"),
                Hits = p.String("hits", "foes"),
                OnResolve = p.Callback("onResolve"),
            };
            h.LingerUntil = h.GoesOffAt + (long)(p.Float("linger", 0) * 1000);
            return h;
        }

        public bool Active => !Resolved || GameClock.NowMs < LingerUntil;

        public bool Affects(Character c)
        {
            if (c == null || c.IsDead())
                return false;
            switch (Hits)
            {
                case "all": return true;
                case "players": return c is Player;
                default: return Source == null ? !(c.factionId == Factions.Monster) : Factions.IsHostile(Source, c) || Factions.Between(Source, c) == Relation.Neutral && c is Player;
            }
        }

        public bool Covers(Vector3 p, Character who) => Active && (who == null || Affects(who)) && Shape.Contains(p);

        public List<Character> Resolve(IEnumerable<Character> candidates)
        {
            Resolved = true;
            var hits = new List<Character>();
            foreach (var c in candidates)
                if (Affects(c) && Shape.Contains(c.GetPosAsVector3()))
                    hits.Add(c);

            var results = new List<CommandResult>();
            foreach (var c in hits)
            {
                int amount = Damage + (int)(c.GetMaxHP() * DamagePercent / 100f);
                if (amount <= 0)
                    continue;
                var r = new CommandResult(c.Id, 30319, (uint)(HitEffect.HitEffectType | HitEffect.Hit), (ushort)Math.Min(amount, ushort.MaxValue));
                results.Add(r);
                c.DelHP(amount);
                if (Source != null)
                    c.hateContainer?.UpdateHate(Source, 0);
                EventBus.Raise(new ActorEvent(ActorEventType.Damaged, c, Source) { Amount = amount, Name = Name ?? "hazard" });
            }
            if (Source != null && (Animation != 0 || results.Count > 0))
                Source.DoBattleAction(Command, Animation, results);
            return hits;
        }
    }

    // A named area that raises EnteredRegion and LeftRegion. A closed door is a region actors
    // may not enter.
    class Region
    {
        public string Name;
        public Shape Shape;
        public bool Blocks;
        public string OpenAnimation;
        public uint MapObjectId;
        public readonly HashSet<uint> Inside = new HashSet<uint>();
    }

    enum ObjectiveRole { Score, Wins, Required, Fails }
    enum ObjectiveState { Pending, Complete, Failed }

    // A goal with a state. kill, protect, reach, survive, hold, count or custom.
    class Objective
    {
        public string Name;
        public string Kind;
        public ObjectiveRole Role;
        public ObjectiveState State;
        public string Group;
        public int Min = 1;
        public int N;
        public Vector3 Point;
        public float Radius = 3;
        public double Seconds;
        public string Region;
        public string Counter;
        public ScriptCallback Fn;
        public long HeldSince;
        public readonly HashSet<uint> Reached = new HashSet<uint>();

        public static Objective From(string name, string kind, ScriptParams p, string role)
        {
            var o = new Objective
            {
                Name = name,
                Kind = kind,
                Group = p.String("group"),
                Min = p.Int("min", 1),
                N = p.Int("n"),
                Point = p.Point("point"),
                Radius = p.Float("radius", 3),
                Seconds = p.Float("seconds"),
                Region = p.String("region"),
                Counter = p.String("counter"),
                Fn = p.Callback("fn"),
            };
            o.Role = Enum.TryParse<ObjectiveRole>(role ?? "score", true, out var r) ? r : ObjectiveRole.Score;
            if (role == null)
                o.Role = kind == "protect" ? ObjectiveRole.Fails : kind == "kill" ? ObjectiveRole.Required : ObjectiveRole.Score;
            return o;
        }

        public object Snapshot() => new { name = Name, kind = Kind, role = Role.ToString(), state = State.ToString(), group = Group, counter = Counter };
    }
}
