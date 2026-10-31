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
using Meteor.Map.actors.chara.ai;
using Meteor.Map.Scripting;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.packets.send.actor.battle;

namespace Meteor.Map.AI.Behaviors
{
    // Stands at home facing its home rotation; plays idle animations from a list.
    class Idle : Behavior
    {
        public override int DefaultPriority => Bands.Ambient + 10;
        public override Channels DefaultChannels => Channels.Face | Channels.Speak;
        private long nextEmote;
        private bool faced;

        public override Channels Wants() => Actor.IsEngaged() || brain.Mover?.IsMoving == true ? Channels.None : DefaultChannels;

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Face) != 0 && !faced && BehaviorUtil.Dist(Actor, brain.Home) < 1.5f)
            {
                Actor.rotation = Actor.spawnRotation;
                faced = true;
            }
            var emotes = Params.Table("emotes");
            if ((granted & Channels.Speak) != 0 && emotes != null && emotes.List.Count > 0 && Now >= nextEmote)
            {
                nextEmote = Now + (long)(Params.Range("interval", Rng, 20) * 1000);
                if (emotes.List[Rng.Int(0, emotes.List.Count - 1)] is double anim)
                    Actor.PlayAnimation((uint)anim);
            }
        }

        public override void OnLose(Channels lost)
        {
            faced = false;
        }
    }

    // Walks to random points around home.
    class Roam : Behavior
    {
        public override int DefaultPriority => Bands.Ambient + 20;
        public override Channels DefaultChannels => Channels.Move;
        private long nextMove;

        public override Channels Wants() => Actor.IsEngaged() ? Channels.None : Channels.Move;

        public override void OnAdd()
        {
            nextMove = Now + (long)(Params.Range("delay", Rng, 10) * 1000);
        }

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Move) == 0 || !brain.CanMove() || brain.Mover.IsMoving || Now < nextMove)
                return;
            nextMove = Now + (long)(Params.Range("delay", Rng, 10) * 1000);
            if (!PlayersNearby())
                return;
            float radius = Params.Float("radius", 15);
            var centre = Params.Point("centre") ?? brain.Home;
            var dest = Actor.FindRandomPoint(centre.X, centre.Y, centre.Z, Math.Min(1.5f, radius), radius);
            if (dest != null)
                brain.Mover.MoveTo(dest, Brain.Pace(Params.String("pace", "walk")));
        }

        // Monsters with no player this close stay put: thousands walking at once, each step checked
        // against the zone's collision, starved the zone thread.
        private const int ACTIVITY_RANGE = 100;

        private bool PlayersNearby()
        {
            if (!(Actor is BattleNpc) || Actor is Ally || Actor.CurrentArea == null)
                return true;
            return Actor.CurrentArea.GetActorsAroundActor<Player>(Actor, ACTIVITY_RANGE).Count > 0;
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }
    }

    // Walks a route. mode: loop, pingpong or once.
    class Patrol : Behavior
    {
        public override int DefaultPriority => Bands.Ambient + 30;
        public override Channels DefaultChannels => Channels.Move;
        private List<RoutePoint> route = new List<RoutePoint>();
        private int index, step = 1;
        private long waitUntil;
        private bool done;

        public override void Configure(ScriptParams p)
        {
            base.Configure(p);
            route = BehaviorUtil.Route(Params.Table("route"));
        }

        public override Channels Wants() => done || route.Count == 0 || Actor.IsEngaged() ? Channels.None : Channels.Move;

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Move) == 0 || !brain.CanMove() || Now < waitUntil)
                return;
            var point = route[index];
            if (BehaviorUtil.FlatDist(Actor.GetPosAsVector3(), point.Pos) <= 1.0f)
            {
                EventBus.Raise(new ActorEvent(ActorEventType.WaypointReached, Actor) { Name = point.Name, Amount = index, Data = Id });
                waitUntil = Now + (long)((point.Wait > 0 ? point.Wait : Params.Float("wait", 0)) * 1000);
                Advance();
                return;
            }
            brain.Mover.MoveTo(point.Pos, Brain.Pace(Params.String("pace", "walk")));
        }

        private void Advance()
        {
            string mode = Params.String("mode", "loop");
            int next = index + step;
            if (next >= route.Count || next < 0)
            {
                if (mode == "once") { done = true; Finish("arrived"); return; }
                if (mode == "pingpong") { step = -step; next = index + step; }
                else next = 0;
            }
            index = Math.Max(0, Math.Min(route.Count - 1, next));
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }

        public override string Describe() => $"point {index}/{route.Count}";
    }

    // Runs senses; on a valid target adds hate and raises Aggro. Staggered across ticks.
    class Detect : Behavior
    {
        public override int DefaultPriority => Bands.Ambient + 40;
        public override Channels DefaultChannels => Channels.Sense;
        private long nextScan;

        public override Channels Wants()
        {
            if (Actor.IsEngaged() || Actor.isMovingToSpawn || brain.Bb.ContainsKey("returning"))
                return Channels.None;
            return Actor.perception.Senses ? Channels.Sense : Channels.None;
        }

        public override void OnAdd()
        {
            nextScan = Now + Rng.Int(0, 500);
        }

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Sense) == 0 || Now < nextScan)
                return;
            nextScan = Now + (long)(Params.Float("interval", 0.5f) * 1000);
            var p = Actor.perception;
            foreach (var c in p.Candidates(p.MaxRange))
            {
                if (!p.Detects(c))
                    continue;
                Actor.hateContainer.AddBaseHate(c);
                EventBus.Raise(new ActorEvent(ActorEventType.Aggro, Actor, c));
                return;
            }
        }
    }

    // Joins a fight a linked neighbour is in: same family, pack, group or tag.
    class Link : Behavior
    {
        public override int DefaultPriority => Bands.Ambient + 41;
        public override Channels DefaultChannels => Channels.None;
        public override bool Watches => true;
        private long nextScan;

        public override void Tick(Channels granted)
        {
            if (Actor.IsEngaged() || Now < nextScan)
                return;
            nextScan = Now + 500;
            float radius = Params.Float("radius", 10);
            string by = Params.String("by", "family");
            foreach (var c in Actor.perception.Candidates(radius))
            {
                if (!(c.IsEngaged() && c.TargetChara != null && Linked(c, by) && Factions.IsFriendly(Actor, c)))
                    continue;
                if (!Factions.CanAttack(Actor, c.TargetChara) && !Factions.IsHostile(Actor, c.TargetChara))
                    continue;
                Actor.hateContainer.AddBaseHate(c.TargetChara);
                EventBus.Raise(new ActorEvent(ActorEventType.Aggro, Actor, c.TargetChara) { Name = "link" });
                SendLinkPopup(c, c.TargetChara);
                return;
            }
        }

        // "X calls for help. 1 more enemy joins": the client shows it as the "Link!" popup, but only when
        // the performer is the viewer or a party member, so it goes out from the player (a pet's owner).
        private const ushort TEXT_CALLS_FOR_HELP = 30129;

        private static void SendLinkPopup(Character caller, Character target)
        {
            Character performer = target is Pet && target.ownerChara != null ? target.ownerChara : target;
            if (!(performer is Player) || performer.CurrentArea == null)
                return;
            var result = new CommandResult(caller.Id, TEXT_CALLS_FOR_HELP, 0, 1, 1);
            performer.CurrentArea.BroadcastPacketAroundActor(performer, CommandResultX01Packet.BuildPacket(performer.Id, 0x7C000062, 0, result));
        }

        private bool Linked(Character other, string by)
        {
            switch (by)
            {
                case "pack":
                    return Actor.Brain?.Bb.TryGetValue("pack", out var a) == true && other.Brain?.Bb.TryGetValue("pack", out var b) == true && Equals(a, b);
                case "group":
                    return Actor.content != null && Actor.content == other.content && Actor.content.SharesGroup(Actor, other);
                case "tag":
                    return Params.String("tag") is string t && Actor.HasTag(t) && other.HasTag(t);
                default:
                    return other is BattleNpc ob && Actor is BattleNpc mb && ob.genusId == mb.genusId;
            }
        }
    }
}
