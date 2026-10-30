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

namespace Meteor.Map.AI.Behaviors
{
    // A short plan of steps run in order: { go = point }, { face = "target" | point | angle },
    // { wait = s }, { use = actionId, on = "target" }, { anim = id }, { call = fn }, { hold = true }.
    // Removes itself after the last step unless a step holds.
    class Mechanic : Behavior
    {
        public override int DefaultPriority => Bands.Mechanic;
        public override Channels DefaultChannels => Channels.Move | Channels.Face | Channels.Act | Channels.Target;
        private List<ScriptParams> steps = new List<ScriptParams>();
        private int index;
        private long waitUntil;
        private bool holding;

        public override void Configure(ScriptParams p)
        {
            base.Configure(p);
            steps.Clear();
            foreach (var s in (Params.Table("steps") ?? Params).List)
                if (s is ScriptParams sp)
                    steps.Add(sp);
        }

        public override void Tick(Channels granted)
        {
            if (holding)
                return;
            if (Now < waitUntil)
                return;
            if (index >= steps.Count)
            {
                Finish("done");
                return;
            }
            var step = steps[index];
            if (step.Has("go"))
            {
                var p = step.Point("go");
                if (p != null && BehaviorUtil.Dist(Actor, p) > step.Float("within", 1.0f))
                {
                    if ((granted & Channels.Move) != 0 && brain.CanMove())
                        brain.Mover.MoveTo(p, Brain.Pace(step.String("pace", "run")));
                    else if ((granted & Channels.Move) != 0 && step.Bool("warp", false))
                        brain.Mover.Teleport(p, Actor.rotation);
                    return;
                }
                if (brain.Mover?.IsMoving == true)
                    brain.Mover.Stop();
            }
            if (step.Has("face") && (granted & Channels.Face) != 0)
            {
                var f = step.Get("face");
                if (f is double angle)
                    Actor.rotation = (float)angle;
                else if (f is string s)
                    brain.Face(BehaviorUtil.ResolveActor(brain, s));
                else if (ScriptParams.AsPoint(f) is Vector3 pt)
                    Actor.LookAt(pt);
            }
            if (step.Has("use") && (granted & Channels.Act) != 0)
            {
                var target = BehaviorUtil.ResolveActor(brain, step.Get("on") ?? "target") ?? Actor;
                if (!brain.UseAction((uint)step.Int("use"), target, true))
                    return;
            }
            if (step.Has("anim"))
                Actor.PlayAnimation((uint)step.Int("anim"));
            step.Callback("call")?.Invoke(Actor);
            if (step.Bool("hold", false))
            {
                holding = true;
                if (brain.Mover?.IsMoving == true)
                    brain.Mover.Stop();
            }
            waitUntil = Now + (long)(step.Float("wait", 0) * 1000);
            index++;
        }

        public override string Describe() => holding ? "holding" : $"step {index}/{steps.Count}";
    }

    // Freezes the chosen channels (default move, face and act).
    class Hold : Behavior
    {
        public override int DefaultPriority => Bands.Script;
        public override Channels DefaultChannels => Channels.Move | Channels.Face | Channels.Act;
        private Channels channels;

        public override void Configure(ScriptParams p)
        {
            base.Configure(p);
            channels = Parse(Params.Table("channels")) ?? DefaultChannels;
        }

        public static Channels? Parse(ScriptParams list)
        {
            if (list == null || list.List.Count == 0)
                return null;
            Channels c = Channels.None;
            foreach (var v in list.List)
                if (v is string s && Enum.TryParse<Channels>(s, true, out var one))
                    c |= one;
            return c;
        }

        public override Channels Wants() => channels;

        public override void OnAdd()
        {
            if ((channels & Channels.Move) != 0 && brain.Mover?.IsMoving == true)
                brain.Mover.Stop();
        }

        public override void Tick(Channels granted) { }
    }

    // Scripted move along points, ignoring threat.
    class Walk : Behavior
    {
        public override int DefaultPriority => Bands.Script - 30;
        public override Channels DefaultChannels => Channels.Move | Channels.Face;
        private List<RoutePoint> points = new List<RoutePoint>();
        private int index;

        public override void Configure(ScriptParams p)
        {
            base.Configure(p);
            points = BehaviorUtil.Route(Params.Table("points") ?? Params.Table("route"));
        }

        public override void Tick(Channels granted)
        {
            if ((granted & Channels.Move) == 0)
                return;
            if (index >= points.Count)
            {
                if (Params.Get("faceAt") is double angle)
                    Actor.rotation = (float)angle;
                Finish("arrived");
                return;
            }
            var p = points[index];
            if (BehaviorUtil.FlatDist(Actor.GetPosAsVector3(), p.Pos) <= 1.0f)
            {
                EventBus.Raise(new ActorEvent(ActorEventType.WaypointReached, Actor) { Name = p.Name, Amount = index, Data = Id });
                index++;
                return;
            }
            if (brain.CanMove())
                brain.Mover.MoveTo(p.Pos, Brain.Pace(Params.String("pace", "walk")), 0, 1.5f, null, Params.Bool("ignoreNav", false));
        }
    }

    // Status control: runs from the source.
    class Fear : Behavior
    {
        public override int DefaultPriority => Bands.Control;
        public override Channels DefaultChannels => Channels.Move | Channels.Target | Channels.Act | Channels.Sense;

        public override void OnAdd()
        {
            brain.Disengage();
        }

        public override void Tick(Channels granted)
        {
            var source = BehaviorUtil.ResolveActor(brain, Params.Get("source"));
            if (source == null || !brain.CanMove() || brain.Mover.IsMoving)
                return;
            brain.Mover.MoveTo(BehaviorUtil.Away(Actor, source, 10), Mover.MOVE_STATE_RUN);
        }
    }

    // Status control: fights for the source's side for its duration.
    class Charm : Behavior
    {
        private const string FollowId = "charm.follow";
        public override int DefaultPriority => Bands.Control;
        public override Channels DefaultChannels => Channels.Sense | Channels.Target;
        private int savedFaction = -1;
        private object savedLeader;

        public override void OnAdd()
        {
            var source = BehaviorUtil.ResolveActor(brain, Params.Get("source"));
            if (source == null)
            {
                Finish("no source");
                return;
            }
            savedFaction = Actor.factionId;
            Actor.factionId = source.factionId;
            brain.Bb.TryGetValue("leader", out savedLeader);
            brain.Bb["leader"] = source;
            var follow = new ScriptParams();
            follow.Set("leader", "leader");
            follow.Set("gap", (double)Params.Float("gap", 3));
            brain.Add("Follow", FollowId, follow);
            brain.Disengage();
        }

        public override void Tick(Channels granted)
        {
            var source = BehaviorUtil.ResolveActor(brain, Params.Get("source"));
            if (source?.target != null && source.IsEngaged() && Factions.CanAttack(Actor, source.TargetChara))
                Actor.hateContainer.AddBaseHate(source.TargetChara);
        }

        public override void OnRemove()
        {
            if (savedFaction >= 0)
                Actor.factionId = savedFaction;
            if (savedLeader != null)
                brain.Bb["leader"] = savedLeader;
            else
                brain.Bb.Remove("leader");
            brain.Remove(FollowId, "charm ended");
            brain.Disengage();
        }
    }

    // Status control: wanders and strikes whatever is close.
    class Confuse : Behavior
    {
        public override int DefaultPriority => Bands.Control;
        public override Channels DefaultChannels => Channels.Move | Channels.Target | Channels.Sense;
        private long next;

        public override void Tick(Channels granted)
        {
            if (Now < next)
                return;
            next = Now + 2000;
            var near = Actor.perception.Candidates(5);
            if (near.Count > 0 && Rng.Chance(0.5))
            {
                Actor.hateContainer.ClearHate();
                Actor.hateContainer.AddBaseHate(near[Rng.Int(0, near.Count - 1)]);
            }
            else if (brain.CanMove())
                brain.Mover.MoveTo(Actor.FindRandomPointAroundActor(2, 6), Mover.MOVE_STATE_WALK);
        }
    }

    // A behavior written in Lua. The runtime object decides what it wants at its think rate.
    class ScriptBehavior : Behavior
    {
        private int objectId;
        private int priority;
        private Channels declared;
        private Channels wants;
        private long nextThink;

        public override int DefaultPriority => priority;
        public override Channels DefaultChannels => declared;
        public override bool Watches => true;

        public void Bind(int objectId, int priority, int channels)
        {
            this.objectId = objectId;
            this.priority = priority;
            declared = (Channels)channels;
            wants = declared;
        }

        public override Channels Wants() => wants;

        public override void Tick(Channels granted)
        {
            if (Now < nextThink)
                return;
            nextThink = Now + (long)(Params.Float("think", 1.0f) * 1000);
            var r = ScriptRuntime.Instance.Call("rt_behavior_think", objectId, (int)granted);
            if (r != null && r.Length > 0)
            {
                if (r[0] is double mask)
                    wants = (Channels)(int)mask & Channels.All;
                else if (r[0] is bool b && !b)
                    wants = Channels.None;
            }
        }

        public override void OnEvent(ActorEvent e)
        {
            ScriptRuntime.Instance.Call("rt_behavior_event", objectId, e);
        }

        public override void OnRemove()
        {
            ScriptRuntime.Instance.Destroy(objectId);
        }
    }

    static class BehaviorRegistry
    {
        private static readonly Dictionary<string, Func<Behavior>> kinds = new Dictionary<string, Func<Behavior>>(StringComparer.OrdinalIgnoreCase)
        {
            ["Idle"] = () => new Idle(),
            ["Roam"] = () => new Roam(),
            ["Patrol"] = () => new Patrol(),
            ["Detect"] = () => new Detect(),
            ["Link"] = () => new Link(),
            ["Combat"] = () => new Combat(),
            ["Leash"] = () => new Leash(),
            ["Follow"] = () => new Follow(),
            ["Assist"] = () => new Assist(),
            ["Ready"] = () => new Ready(),
            ["Guard"] = () => new Guard(),
            ["Escort"] = () => new Escort(),
            ["Command"] = () => new Command(),
            ["Flee"] = () => new Flee(),
            ["Avoid"] = () => new Avoid(),
            ["Mechanic"] = () => new Mechanic(),
            ["Hold"] = () => new Hold(),
            ["Walk"] = () => new Walk(),
            ["Fear"] = () => new Fear(),
            ["Charm"] = () => new Charm(),
            ["Confuse"] = () => new Confuse(),
            ["Script"] = () => new ScriptBehavior(),
        };

        public static bool IsStock(string kind) => kinds.ContainsKey(kind ?? "");

        public static IEnumerable<string> Kinds => kinds.Keys;

        public static Behavior Create(string kind, Brain brain)
        {
            return kinds.TryGetValue(kind ?? "", out var make) ? make() : null;
        }
    }
}
