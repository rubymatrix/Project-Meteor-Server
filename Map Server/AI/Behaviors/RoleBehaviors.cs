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
using Meteor.Map.packets.send.actor;
using Meteor.Map.utils;

namespace Meteor.Map.AI.Behaviors
{
    // Keeps a formation slot near a leader. Runs to catch up; warps when far behind if allowed.
    class Follow : Behavior
    {
        public override int DefaultPriority => Bands.Role;
        public override Channels DefaultChannels => Channels.Move | Channels.Face;

        private Character Leader => BehaviorUtil.ResolveActor(brain, Params.Get("leader") ?? "leader");

        public override Channels Wants()
        {
            var leader = Leader;
            if (leader == null || !leader.IsAlive() || leader.CurrentArea != Actor.CurrentArea)
                return Channels.None;
            if (Actor.IsEngaged() && !Params.Bool("inCombat", false))
                return Channels.None;
            return DefaultChannels;
        }

        public override void Tick(Channels granted)
        {
            var leader = Leader;
            if (leader == null || (granted & Channels.Move) == 0)
                return;
            float gap = Params.Float("gap", 3);
            var (right, back) = BehaviorUtil.Slot(Params.String("slot", "rear"), gap);
            var spot = BehaviorUtil.Offset(leader, right, back);
            float dist = BehaviorUtil.Dist(Actor, leader);
            float warp = Params.Float("warp", 0);
            if (warp > 0 && dist > warp)
            {
                brain.Mover.Teleport(spot, leader.rotation);
                return;
            }
            if (BehaviorUtil.Dist(Actor, spot) <= 1.0f || dist <= gap * 0.75f)
            {
                if (brain.Mover.IsMoving)
                    brain.Mover.Stop();
                if ((granted & Channels.Face) != 0 && !leader.IsEngaged())
                    Actor.rotation = leader.rotation;
                return;
            }
            if (!brain.CanMove())
                return;
            ushort pace = dist > Params.Float("catchUp", gap * 2) || leader.moveState == Mover.MOVE_STATE_RUN ? Mover.MOVE_STATE_RUN : Mover.MOVE_STATE_WALK;
            brain.Mover.MoveTo(spot, pace, 0.5f, 2.0f);
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }

        public override string Describe() => Leader?.GetName() ?? "no leader";
    }

    // Weapon drawn and in position while the leader squares up to a foe, without striking. Stops at
    // melee range, or at range for casters. Combat takes over once there is hate.
    class Ready : Behavior
    {
        public const string BbKey = "ready";
        public override int DefaultPriority => Bands.Role + 5;
        public override Channels DefaultChannels => Channels.Move | Channels.Face;

        private Character Foe()
        {
            var leader = BehaviorUtil.ResolveActor(brain, Params.Get("leader") ?? "leader");
            if (leader == null || !leader.IsAlive() || !leader.IsEngaged())
                return null;
            var t = leader.TargetChara;
            return t != null && t.IsAlive() && Factions.IsHostile(Actor, t) ? t : null;
        }

        public override Channels Wants()
        {
            if (Actor.hateContainer.GetHateList().Count > 0 || brain.Bb.ContainsKey("fleeing"))
                return Channels.None;
            if (Actor.IsEngaged() && !brain.Bb.ContainsKey(BbKey))
                return Channels.None;
            return Foe() != null || brain.Bb.ContainsKey(BbKey) ? DefaultChannels : Channels.None;
        }

        public override void Tick(Channels granted)
        {
            var foe = Foe();
            if (foe == null)
            {
                StandDown();
                return;
            }
            brain.Bb[BbKey] = true;
            if (Actor.GetState() != SetActorStatePacket.MAIN_STATE_ACTIVE)
                Actor.ChangeState(SetActorStatePacket.MAIN_STATE_ACTIVE);
            if ((granted & Channels.Move) == 0 || !brain.CanMove())
            {
                brain.Face(foe);
                return;
            }
            float range = Params.Float("range", Math.Max(0.0f, Actor.GetAttackRange() - 0.2f));
            var pos = foe.GetPosAsVector3();
            if (Utils.Distance(Actor.GetPosAsVector3(), pos) <= range)
            {
                if (brain.Mover.IsMoving)
                    brain.Mover.Stop();
                brain.Face(foe);
            }
            else if (!brain.Mover.Chase(pos, Mover.MOVE_STATE_RUN, range))
                brain.Face(foe);
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && Actor.hateContainer.GetHateList().Count == 0)
                StandDown();
        }

        private void StandDown()
        {
            if (!brain.Bb.Remove(BbKey))
                return;
            if (brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
            if (Actor.GetState() == SetActorStatePacket.MAIN_STATE_ACTIVE)
                Actor.ChangeState(SetActorStatePacket.MAIN_STATE_PASSIVE);
        }

        public override string Describe() => brain.Bb.ContainsKey(BbKey) ? "ready" : "at ease";
    }

    // Engages what its leader, or any member of a content group, is fighting.
    class Assist : Behavior
    {
        public override int DefaultPriority => Bands.Role + 10;
        public override Channels DefaultChannels => Channels.Sense | Channels.Target;
        private long engageAt;

        public override Channels Wants() => (Actor.IsEngaged() && !brain.Bb.ContainsKey(Ready.BbKey)) || brain.Bb.ContainsKey("fleeing") || Params.Bool("passive", false) ? Channels.None : DefaultChannels;

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Target) == 0)
                return;
            Character foe = FindFoe();
            if (foe == null)
            {
                engageAt = 0;
                return;
            }
            if (engageAt == 0)
                engageAt = Now + (long)(Params.Float("delay", 0) * 1000);
            if (Now < engageAt)
                return;
            engageAt = 0;
            Actor.hateContainer.AddBaseHate(foe);
            EventBus.Raise(new ActorEvent(ActorEventType.Aggro, Actor, foe) { Name = "assist" });
        }

        private Character FindFoe()
        {
            bool onlyAttacked = Params.Bool("onlyWhenAttacked", false);
            foreach (var friend in Friends())
            {
                if (friend == null || !friend.IsAlive())
                    continue;
                var t = friend.TargetChara;
                if (t != null && t.IsAlive() && friend.IsEngaged() && Factions.CanAttack(Actor, t) && Factions.Between(Actor, t) != Relation.Friendly)
                {
                    if (!onlyAttacked || (t.hateContainer?.HasHateForTarget(friend) ?? false))
                        return t;
                }
                // A foe that has hate on the friend counts even before the friend swings.
                if (friend.CurrentArea != null)
                    foreach (var c in friend.CurrentArea.GetActorsAroundActor<Character>(friend, (int)Params.Float("range", 30)))
                        if (c.IsAlive() && c.hateContainer != null && c.hateContainer.HasHateForTarget(friend) && Factions.IsHostile(Actor, c))
                            return c;
            }
            return null;
        }

        private IEnumerable<Character> Friends()
        {
            string group = Params.String("group");
            if (group != null && Actor.content != null)
            {
                foreach (var c in Actor.content.Group(group))
                    if (c != Actor)
                        yield return c;
                if (group == "participants")
                    foreach (var p in Actor.content.ParticipantList())
                        yield return p;
            }
            else
                yield return BehaviorUtil.ResolveActor(brain, Params.Get("leader") ?? "leader");
        }
    }

    // Holds a point, or stays by an actor, and attacks hostiles inside the radius.
    class Guard : Behavior
    {
        public override int DefaultPriority => Bands.Role + 20;
        public override Channels DefaultChannels => Channels.Sense | Channels.Target | Channels.Move;
        private long nextScan;

        private Vector3 Point()
        {
            var a = BehaviorUtil.ResolveActor(brain, Params.Get("actor"));
            return a?.GetPosAsVector3() ?? Params.Point("point") ?? brain.Home;
        }

        public override Channels Wants()
        {
            if (Actor.IsEngaged())
                return Channels.None;
            return DefaultChannels;
        }

        public override void Tick(Channels granted)
        {
            var point = Point();
            float radius = Params.Float("radius", 12);
            if ((granted & Channels.Sense) != 0 && Now >= nextScan)
            {
                nextScan = Now + 500;
                foreach (var c in Actor.perception.Candidates(radius + BehaviorUtil.Dist(Actor, point)))
                {
                    if (!Factions.IsHostile(Actor, c) || BehaviorUtil.Dist(c, point) > radius || !Actor.perception.PassesFilter(c))
                        continue;
                    Actor.hateContainer.AddBaseHate(c);
                    EventBus.Raise(new ActorEvent(ActorEventType.Aggro, Actor, c) { Name = "guard" });
                    return;
                }
            }
            if ((granted & Channels.Move) != 0 && brain.CanMove() && BehaviorUtil.Dist(Actor, point) > Params.Float("slack", 2))
                brain.Mover.MoveTo(point, Brain.Pace(Params.String("pace", "run")), 1.0f);
        }
    }

    // Walks a route, halting while its halt condition holds.
    class Escort : Behavior
    {
        public override int DefaultPriority => Bands.Role + 30;
        public override Channels DefaultChannels => Channels.Move;
        private List<RoutePoint> route = new List<RoutePoint>();
        private int index;
        private long resumeAt, waitUntil;
        private bool halted;

        public bool Halted => halted;
        public int Index => index;

        public override void Configure(ScriptParams p)
        {
            base.Configure(p);
            var r = BehaviorUtil.Route(Params.Table("route"));
            if (r.Count > 0)
                route = r;
            if (Params.Has("start"))
                index = Math.Max(0, Math.Min(route.Count - 1, Params.Int("start")));
        }

        public override Channels Wants() => route.Count == 0 || Actor.IsEngaged() || brain.Bb.ContainsKey("fleeing") ? Channels.None : Channels.Move;

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Move) == 0)
                return;
            var halt = Params.Callback("haltWhen");
            bool mustHalt = halt != null && halt.Test(Actor);
            var waitFor = Params.Table("waitFor");
            if (!mustHalt && waitFor != null)
                mustHalt = !Nearby(waitFor);
            if (mustHalt)
            {
                if (!halted)
                {
                    halted = true;
                    if (brain.Mover.IsMoving)
                        brain.Mover.Stop();
                    EventBus.Raise(new ActorEvent(ActorEventType.Signal, Actor) { Name = "halted" });
                }
                resumeAt = Now + (long)(Params.Float("resume", 3) * 1000);
                return;
            }
            if (halted)
            {
                if (Now < resumeAt)
                    return;
                halted = false;
                EventBus.Raise(new ActorEvent(ActorEventType.Signal, Actor) { Name = "resumed" });
            }
            if (Now < waitUntil || !brain.CanMove())
                return;
            var point = route[index];
            if (BehaviorUtil.FlatDist(Actor.GetPosAsVector3(), point.Pos) <= 1.2f)
            {
                EventBus.Raise(new ActorEvent(ActorEventType.WaypointReached, Actor) { Name = point.Name, Amount = index, Data = Id });
                waitUntil = Now + (long)(point.Wait * 1000);
                if (index == route.Count - 1)
                {
                    Finish("arrived");
                    return;
                }
                index++;
                return;
            }
            brain.Mover.MoveTo(point.Pos, Brain.Pace(Params.String("pace", "walk")), 0, 1.5f);
        }

        private bool Nearby(ScriptParams waitFor)
        {
            float range = waitFor.Float("range", 20);
            string group = waitFor.String("group", "participants");
            if (Actor.content == null)
                return true;
            IEnumerable<Character> who = group == "participants" ? Actor.content.ParticipantList() : Actor.content.Group(group);
            foreach (var c in who)
                if (c != null && c.IsAlive() && c.CurrentArea == Actor.CurrentArea && BehaviorUtil.Dist(Actor, c) <= range)
                    return true;
            return false;
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }

        public override string Describe() => (halted ? "halted " : "") + $"point {index}/{route.Count}";
    }

    // Obeys its owner: attack, heel, stay.
    class Command : Behavior
    {
        public override int DefaultPriority => Bands.Role + 40;
        public override Channels DefaultChannels => Channels.Target | Channels.Move;
        private string order;
        private Character orderTarget;
        private Vector3 stayAt;

        public void Give(string newOrder, Character target)
        {
            order = newOrder;
            orderTarget = target;
            switch (order)
            {
                case "attack":
                    if (target != null && Factions.CanAttack(Actor, target))
                        Actor.hateContainer.AddBaseHate(target);
                    break;
                case "heel":
                    brain.Disengage();
                    break;
                case "stay":
                    stayAt = Actor.GetPosAsVector3();
                    break;
            }
        }

        public override Channels Wants() => order == "heel" || order == "stay" ? DefaultChannels : Channels.None;

        public override void Tick(Channels granted)
        {
            if (order == "heel")
            {
                Actor.hateContainer.ClearHate();
                var owner = Actor.ownerChara;
                if (owner == null || BehaviorUtil.Dist(Actor, owner) < 3)
                    order = null;
                else if ((granted & Channels.Move) != 0 && brain.CanMove())
                    brain.Mover.MoveTo(owner.GetPosAsVector3(), Mover.MOVE_STATE_RUN, 2);
            }
            else if (order == "stay" && (granted & Channels.Move) != 0 && stayAt != null && BehaviorUtil.Dist(Actor, stayAt) > 1.5f && brain.CanMove())
                brain.Mover.MoveTo(stayAt, Mover.MOVE_STATE_WALK);
        }

        public override string Describe() => order ?? "";
    }
}
