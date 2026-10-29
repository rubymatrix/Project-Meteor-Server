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
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.Content;
using Meteor.Map.Scripting;
using Meteor.Map.utils;
using Meteor.Map.actors.chara.npc;

namespace Meteor.Map.AI.Behaviors
{
    // Fights the top of the hate table: engages, chases into range, faces, and asks the action
    // picker what to use.
    class Combat : Behavior
    {
        public override int DefaultPriority => Bands.Combat;
        public override Channels DefaultChannels => Channels.Move | Channels.Face | Channels.Target | Channels.Act;
        private long nextPick;

        public override Channels Wants()
        {
            if (brain.Bb.ContainsKey("returning") || brain.Bb.ContainsKey("fleeing"))
                return Channels.None;
            if (Actor.hateContainer.GetHateList().Count > 0 || (Actor.IsEngaged() && !brain.Bb.ContainsKey(Ready.BbKey)))
                return DefaultChannels;
            return Channels.None;
        }

        public override void Tick(Channels granted)
        {
            var hate = Actor.hateContainer;
            hate.Prune(Actor);
            Character target = hate.GetTarget();
            if (target == null)
            {
                if (Actor.IsEngaged() && (granted & Channels.Target) != 0)
                {
                    brain.Disengage();
                    brain.Bb["returnHome"] = true;
                }
                return;
            }

            if ((granted & Channels.Target) != 0)
            {
                if (!Actor.IsEngaged() || brain.Bb.ContainsKey(Ready.BbKey))
                    brain.Engage(target);
                else if (Actor.target != target)
                    brain.ChangeTarget(target);
            }

            if ((granted & Channels.Move) != 0)
                Chase(target);
            else if ((granted & Channels.Face) != 0 && brain.Mover?.IsMoving != true)
                brain.Face(target);

            if ((granted & Channels.Act) != 0 && Now >= nextPick && brain.HasHook("pick") && Actor.aiContainer.CanChangeState())
            {
                nextPick = Now + (long)(Params.Float("pickInterval", 1.0f) * 1000);
                var r = ScriptRuntime.Instance.Call("rt_actor_pick", brain.ScriptId);
                if (r != null && r.Length >= 2 && r[0] is double id && r[1] is Character t)
                    brain.UseAction((uint)id, t);
            }
        }

        private void Chase(Character target)
        {
            if (!brain.CanMove())
            {
                brain.Face(target);
                return;
            }
            var range = Params.Get("range");
            float max = Math.Max(0.0f, Actor.GetAttackRange() - 0.2f), min = 0;
            if (range is double d)
                max = (float)d;
            else if (range is ScriptParams rp && rp.List.Count >= 2)
            {
                min = rp.Number(0);
                max = rp.Number(1);
            }
            var targetPos = target.GetPosAsVector3();
            float dist = Utils.Distance(Actor.GetPosAsVector3(), targetPos);
            brain.Mover.WatchChase(targetPos);
            if (min > 0 && dist < min)
            {
                brain.Mover.MoveTo(BehaviorUtil.Away(Actor, target, min - dist + 1), Mover.MOVE_STATE_RUN);
                return;
            }
            if (min <= 0 && Params.Bool("spread", !(Actor is Ally)) && Spread(target, targetPos, dist, max))
                return;
            if (dist <= max)
            {
                if (brain.Mover.IsMoving)
                    brain.Mover.Stop();
                brain.Face(target);
                return;
            }
            if (!brain.Mover.Chase(targetPos, Mover.MOVE_STATE_RUN, max))
                brain.Face(target);
        }

        // Several melee mobs on one standing target each take their own stop around it.
        private sealed class SpreadSolution
        {
            public DateTime At;
            public Dictionary<uint, MeleeSpread.Stop> Stops;
        }
        private static readonly Dictionary<uint, SpreadSolution> spreads = new Dictionary<uint, SpreadSolution>();
        private const float SPREAD_GROUP_RANGE = 8.0f, SPREAD_ARRIVE = 0.4f, SPREAD_KEEP = 0.4f, MOB_BODY = 0.5f;
        private const double SPREAD_FRESH_SECONDS = 0.25, SPREAD_STEP_SECONDS = 2.0;
        private const float SPREAD_TRY_STEP = 5.0f * (float)Math.PI / 180.0f;
        private Vector3 spreadStop;
        private DateTime lastSpreadStep = DateTime.MinValue;

        private bool Spread(Character target, Vector3 targetPos, float dist, float max)
        {
            var mover = brain.Mover;
            var myPos = Actor.GetPosAsVector3();
            if (mover.ChaseTargetMoving || !(SpreadStop(target, myPos, targetPos) is Vector3 stop))
            {
                spreadStop = null;
                return false;
            }
            float toStop = MoverMath.XZDistance(myPos, stop);
            bool inRange = dist <= max;
            if (toStop <= SPREAD_ARRIVE || (inRange && !mover.IsMoving && toStop <= SPREAD_KEEP))
            {
                mover.Stop();
                brain.Face(target);
                return true;
            }
            if (inRange && !mover.IsMoving)
            {
                // Stepping aside for a mob that arrived next to it: one step at a time.
                if ((DateTime.Now - lastSpreadStep).TotalSeconds < SPREAD_STEP_SECONDS)
                {
                    mover.Stop();
                    brain.Face(target);
                    return true;
                }
                lastSpreadStep = DateTime.Now;
            }
            if (!mover.MoveTo(stop, Mover.MOVE_STATE_RUN, 0.0f))
                brain.Face(target);
            return true;
        }

        private static float StopDistance(Character c) => Math.Max(0.0f, c.GetAttackRange() - 0.2f);

        // One solution per target per tick, shared by every mob on it, so none chases another's old stop.
        private Vector3 SpreadStop(Character target, Vector3 myPos, Vector3 targetPos)
        {
            MeleeSpread.Stop mine;
            lock (spreads)
            {
                DateTime now = DateTime.Now;
                if (!spreads.TryGetValue(target.Id, out var sol) || (now - sol.At).TotalSeconds > SPREAD_FRESH_SECONDS || !sol.Stops.ContainsKey(Actor.Id))
                {
                    sol = new SpreadSolution { At = now, Stops = new Dictionary<uint, MeleeSpread.Stop>() };
                    var group = SpreadGroup(target);
                    if (group.Count >= 2)
                    {
                        var members = group.Select(bn => new MeleeSpread.Member
                        {
                            Id = bn.Id,
                            X = bn.positionX,
                            Z = bn.positionZ,
                            Radius = StopDistance(bn),
                            MaxRadius = StopDistance(bn),
                            Body = MOB_BODY,
                            Standing = !bn.aiContainer.mover.IsMoving,
                        }).ToList();
                        foreach (var st in MeleeSpread.Solve(targetPos.X, targetPos.Z, members))
                            sol.Stops[st.Id] = st;
                    }
                    spreads[target.Id] = sol;
                    if (spreads.Count > 256)
                        foreach (var id in spreads.Where(kv => (now - kv.Value.At).TotalSeconds > 5).Select(kv => kv.Key).ToList())
                            spreads.Remove(id);
                }
                if (!sol.Stops.TryGetValue(Actor.Id, out mine))
                    return null;
            }
            var stop = UsableStop(mine, myPos, targetPos);
            if (stop != null && spreadStop != null && MoverMath.XZDistance(spreadStop, stop) <= SPREAD_KEEP)
                return spreadStop;
            spreadStop = stop;
            return stop;
        }

        private static List<BattleNpc> SpreadGroup(Character target)
        {
            var group = new List<BattleNpc>();
            if (target.CurrentArea == null)
                return group;
            foreach (var bn in target.CurrentArea.GetActorsAroundActor<BattleNpc>(target, 12))
            {
                if (bn is Ally || bn.IsDead() || bn.target != target || bn.aiContainer == null || !bn.aiContainer.IsEngaged())
                    continue;
                if (Utils.XZDistance(bn.positionX, bn.positionZ, target.positionX, target.positionZ) <= StopDistance(bn) + SPREAD_GROUP_RANGE)
                    group.Add(bn);
            }
            return group;
        }

        // The solved stop if it is on the mesh, reachable and in clear reach of the target; else the
        // nearest bearing back toward the approach line that is, in 5 degree steps.
        private Vector3 UsableStop(MeleeSpread.Stop s, Vector3 myPos, Vector3 targetPos)
        {
            var navMesh = NavmeshUtils.GetNavMesh(Actor.CurrentArea);
            float shift = MeleeSpread.Wrap(s.Theta - s.Theta0);
            int steps = (int)Math.Ceiling(Math.Abs(shift) / SPREAD_TRY_STEP);
            for (int k = 0; k <= steps; k++)
            {
                float theta = s.Theta0 + (steps == 0 ? 0.0f : shift * (steps - k) / steps);
                var p = new Vector3(targetPos.X + s.Radius * (float)Math.Cos(theta), targetPos.Y, targetPos.Z + s.Radius * (float)Math.Sin(theta));
                if (navMesh == null)
                    return p;
                if (!navMesh.TryProject(p, out var ground) || MoverMath.XZDistance(ground, p) > 0.3f)
                    continue;
                float reach = MoverMath.XZDistance(targetPos, ground);
                if (NavmeshUtils.ClearanceTowards(Actor.CurrentArea, targetPos, ground) < reach - 0.05f)
                    continue;
                if (!navMesh.IsReachable(myPos, ground))
                    continue;
                return ground;
            }
            return null;
        }

        public override void OnLose(Channels lost)
        {
            if ((lost & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }
    }

    // Drops the fight and goes home when it strays past its leash, or after a fight ends.
    class Leash : Behavior
    {
        public override int DefaultPriority => Bands.Combat + 50;
        public override Channels DefaultChannels => Channels.Move | Channels.Target | Channels.Sense;
        private bool returning;

        private Vector3 Anchor()
        {
            var a = Params.Get("anchor");
            if (a is string s && s != "home" && BehaviorUtil.ResolveActor(brain, s) is Character c)
                return c.GetPosAsVector3();
            return ScriptParams.AsPoint(a) ?? brain.Home;
        }

        public override Channels Wants()
        {
            if (returning)
                return DefaultChannels;
            float radius = Params.Float("radius", 50);
            float dist = BehaviorUtil.Dist(Actor, Anchor());
            if (Actor.IsEngaged() && radius > 0 && dist > radius)
                return DefaultChannels;
            if (!Actor.IsEngaged() && brain.Bb.ContainsKey("returnHome") && Params.Bool("returnAfterFight", true))
                return dist > 2 ? Channels.Move : Channels.None;
            return Channels.None;
        }

        public override void Tick(Channels granted)
        {
            var anchor = Anchor();
            float dist = BehaviorUtil.Dist(Actor, anchor);
            if (!returning && Actor.IsEngaged() && (granted & Channels.Target) != 0)
            {
                returning = true;
                brain.Bb["returning"] = true;
                brain.Disengage();
            }
            if (returning)
                Actor.hateContainer.ClearHate();
            if ((granted & Channels.Move) == 0)
                return;
            if (dist <= 1.5f)
            {
                brain.Bb.Remove("returnHome");
                if (returning)
                {
                    returning = false;
                    brain.Bb.Remove("returning");
                    if (Params.Bool("reset", true))
                        Actor.SetHP((uint)Actor.GetMaxHP());
                    EventBus.Raise(new ActorEvent(ActorEventType.Recovered, Actor) { Name = "leash" });
                }
                if (brain.Mover.IsMoving)
                    brain.Mover.Stop();
                return;
            }
            if (brain.CanMove())
                brain.Mover.MoveTo(anchor, returning ? Mover.MOVE_STATE_RUN : Mover.MOVE_STATE_WALK);
            else
            {
                returning = false;
                brain.Bb.Remove("returning");
                brain.Bb.Remove("returnHome");
            }
        }

        public override void OnRemove()
        {
            brain.Bb.Remove("returning");
        }

        public override string Describe() => returning ? "returning" : "";
    }

    // Runs from danger when hurt; ends when coaxed back, healed past a line, or after a time.
    class Flee : Behavior
    {
        public override int DefaultPriority => Bands.Survival;
        public override Channels DefaultChannels => Channels.Move | Channels.Target | Channels.Act;
        private bool fleeing;
        private Character threat;
        private long startedAt;

        public bool Fleeing => fleeing;

        public override Channels Wants() => fleeing ? DefaultChannels : Channels.None;

        public override void OnAdd()
        {
            Actor.WatchHp((int)Params.Float("at", 30));
        }

        public override void OnEvent(ActorEvent e)
        {
            if (e.Actor != Actor)
                return;
            if (!fleeing && (e.Type == ActorEventType.Damaged || e.Type == ActorEventType.HpCrossed) && Actor.IsAlive()
                && Actor.GetHPP() <= Params.Float("at", 30))
                Start(e.Other);
            else if (!fleeing && e.Type == ActorEventType.Signal && e.Name == "flee")
                Start(e.Other);
            else if (fleeing && e.Type == ActorEventType.Healed && Params.Bool("coaxOnHeal", true))
                Coax(1);
        }

        public void Coax(int amount)
        {
            if (!fleeing)
                return;
            int n = (brain.Bb.TryGetValue("coax", out var v) && v is int i ? i : 0) + amount;
            brain.Bb["coax"] = n;
        }

        private void Start(Character from)
        {
            fleeing = true;
            threat = from ?? Actor.hateContainer.GetTarget();
            startedAt = Now;
            brain.Bb["fleeing"] = true;
            brain.Bb["coax"] = 0;
            EventBus.Raise(new ActorEvent(ActorEventType.Fled, Actor, threat));
            brain.Disengage();
        }

        public override void Tick(Channels granted)
        {
            if (Recovered())
            {
                fleeing = false;
                brain.Bb.Remove("fleeing");
                brain.Bb.Remove("coax");
                if (brain.Mover?.IsMoving == true)
                    brain.Mover.Stop();
                EventBus.Raise(new ActorEvent(ActorEventType.Recovered, Actor) { Name = "flee" });
                if (Params.Bool("once", false))
                    Finish("recovered");
                return;
            }
            Actor.hateContainer.ClearHate();
            if ((granted & Channels.Move) == 0 || !brain.CanMove() || brain.Mover.IsMoving)
                return;
            var to = Params.Point("to");
            if (to != null)
            {
                if (BehaviorUtil.Dist(Actor, to) > 1.5f)
                    brain.Mover.MoveTo(to, Mover.MOVE_STATE_RUN);
                return;
            }
            if (threat != null && threat.IsAlive() && BehaviorUtil.Dist(Actor, threat) < Params.Float("distance", 15))
                brain.Mover.MoveTo(BehaviorUtil.Away(Actor, threat, Params.Float("distance", 15)), Mover.MOVE_STATE_RUN);
        }

        private bool Recovered()
        {
            var recover = Params.Get("recover") ?? "coaxed";
            if (recover is double seconds)
                return Now - startedAt >= seconds * 1000;
            switch (recover as string)
            {
                case "hp":
                    return Actor.GetHPP() >= Params.Float("recoverHp", 60);
                case "never":
                    return false;
                default:
                    return brain.Bb.TryGetValue("coax", out var v) && v is int n && n >= Params.Int("need", 1);
            }
        }

        public override void OnRemove()
        {
            brain.Bb.Remove("fleeing");
        }

        public override string Describe() => fleeing ? "fleeing" : "";
    }

    // Steps out of active hazards in its area.
    class Avoid : Behavior
    {
        public override int DefaultPriority => Bands.Survival + 50;
        public override Channels DefaultChannels => Channels.Move;
        private long seenAt;
        private Hazard current;

        public override Channels Wants()
        {
            current = ContentManager.HazardAt(Actor.CurrentArea, Actor.GetPosAsVector3(), Actor);
            if (current == null)
            {
                seenAt = 0;
                return Channels.None;
            }
            if (seenAt == 0)
                seenAt = Now;
            return Now - seenAt >= Params.Float("reaction", 0.8f) * 1000 ? Channels.Move : Channels.None;
        }

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Move) == 0 || current == null || !brain.CanMove())
                return;
            var here = Actor.GetPosAsVector3();
            for (float r = 3; r <= 30; r += 3)
            {
                for (int i = 0; i < 12; i++)
                {
                    double a = i * Math.PI / 6;
                    var p = new Vector3(here.X + (float)Math.Cos(a) * r, here.Y, here.Z + (float)Math.Sin(a) * r);
                    if (ContentManager.HazardAt(Actor.CurrentArea, p, Actor) == null)
                    {
                        brain.Mover.MoveTo(p, Mover.MOVE_STATE_RUN);
                        return;
                    }
                }
            }
        }
    }
}
