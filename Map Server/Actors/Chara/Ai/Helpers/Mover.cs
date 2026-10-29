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
using Meteor.Map.navigation;
using Meteor.Map.packets.send.actor;
using Meteor.Map.utils;

namespace Meteor.Map.actors.chara.ai
{
    // Moves every server-controlled character. Controllers set a goal with MoveTo or Chase, and
    // AIContainer calls Update each tick. 0x00CF goes out one hop ahead along the route (MoveCadence),
    // and the actor walks at the client's pace so range and aggro checks match what the player sees.
    class Mover
    {
        // Indexes into the speed table sent in SetActorSpeedPacket.
        public const ushort MOVE_STATE_STOP = 0, MOVE_STATE_WALK = 1, MOVE_STATE_RUN = 2, MOVE_STATE_ACTIVE = 3;

        public enum Outcome { None, Moving, Arrived, Partial, NoRoute, Stuck, Stopped }

        public const float DEFAULT_REPATH_DISTANCE = 1.5f;
        private const float ROUTE_STEP = 2.0f;
        private const int ROUTE_MAX_POINTS = 64;
        private const double NOMINAL_DT = 0.333;
        private const double MAX_DT = 0.5;
        private const double REPATH_INTERVAL = 0.33;
        private const double FAILED_REPATH_INTERVAL = 1.0;
        private const float CORRIDOR = 3.0f;                // goal moved this far: plan again without waiting
        private const float PARTIAL_SLACK = 1.0f;
        private const double STUCK_WINDOW_SECONDS = 2.0;
        private const float STUCK_PROGRESS = 0.1f;

        private readonly Character owner;
        private readonly List<Vector3> route = new List<Vector3>();
        private int routeIndex;
        private bool routePartial;
        private bool routeTruncated;
        private bool needPlan;
        private bool holdOnArrive;
        private bool pendingStop;
        private bool ownsState;

        private Vector3 goal;
        private Vector3 routeGoal;
        private float stopShort;
        private float repathDistance = DEFAULT_REPATH_DISTANCE;
        private bool ignoreNav;
        private ushort state = MOVE_STATE_WALK;
        private Action<Outcome> onDone;

        private DateTime lastTick = DateTime.MinValue;
        private DateTime lastPlan = DateTime.MinValue;
        private Vector3 failedGoal;
        private DateTime failedAt = DateTime.MinValue;
        private Outcome failedOutcome;

        private DateTime stuckSince = DateTime.MinValue;
        private Vector3 stuckPos;
        private float stuckExpected;
        private bool stuckRepathed;

        private const double BLOCKED_GIVE_UP = 2.0;
        private double blockedSince = double.NaN;
        private bool blockedReplanned;
        private int blockedRecoveries;
        private const int MAX_RECOVERIES = 3;
        private DateTime leadFailedAt = DateTime.MinValue;

        private readonly MoveCadence cadence = new MoveCadence();
        private readonly MoveCadence.ChaseLead chaseLead = new MoveCadence.ChaseLead();
        private bool chasing;
        private double stopAt = double.NaN;

        // Planned a part at a time; planned again when the area's gates change.
        private Meteor.Navigation.NavRoute navRoute;
        // Kept tick to tick so a route never starts on the floor above or below.
        private readonly Meteor.Navigation.NavFloor floor = new Meteor.Navigation.NavFloor();

        // Set by scripts. The mob ignores players until the walk ends.
        public bool Scripted;

        public Outcome LastOutcome { get; private set; }
        public PathResult LastPathResult { get; private set; }
        public Vector3 Goal => goal;
        public bool IsMoving => LastOutcome == Outcome.Moving;
        public IReadOnlyList<Vector3> Route => route;

        public bool Failed => LastOutcome == Outcome.NoRoute || LastOutcome == Outcome.Partial || LastOutcome == Outcome.Stuck;
        public bool ChaseTargetMoving => chaseLead.Moving;

        public Mover(Character owner)
        {
            this.owner = owner;
        }

        #region Goals

        // Safe to call every tick with a moving dest: the route is kept while dest stays within
        // repathDistance. Returns false when already there or there is no route (see LastOutcome).
        public bool MoveTo(Vector3 dest, ushort moveState, float stopShort = 0.0f, float repathDistance = DEFAULT_REPATH_DISTANCE,
            Action<Outcome> onDone = null, bool ignoreNav = false)
        {
            if (dest == null || owner.CurrentArea == null || IsCorpse())
                return false;

            DateTime now = DateTime.Now;
            bool sameGoal = routeGoal != null && this.ignoreNav == ignoreNav && Math.Abs(this.stopShort - stopShort) < 0.01f
                && Utils.Distance(routeGoal, dest) <= repathDistance;

            chasing = false;
            state = moveState;
            goal = dest;
            this.stopShort = Math.Max(0.0f, stopShort);
            this.repathDistance = repathDistance;
            this.ignoreNav = ignoreNav;
            this.onDone = onDone;
            holdOnArrive = false;

            if (sameGoal)
            {
                if (LastOutcome == Outcome.Moving)
                    return true;
                if (LastOutcome == Outcome.Arrived)
                    return false;
            }
            else if (LastOutcome == Outcome.Moving && routeGoal != null
                     && MoverMath.XZDistance(routeGoal, dest) <= CORRIDOR && (now - lastPlan).TotalSeconds < REPATH_INTERVAL)
                return true;    // Update plans again once REPATH_INTERVAL is up

            return Plan(now);
        }

        // Call every tick with the target's position. Routes to where the target is heading, not where it
        // is, so hops stay long. The caller stops the mob once in range.
        public bool Chase(Vector3 dest, ushort moveState, float stopShort, Func<bool> crowded = null)
        {
            if (dest == null || owner.CurrentArea == null || IsCorpse())
                return false;
            chaseCrowded = crowded;
            return ChaseLed(dest, WatchChase(dest), moveState, stopShort);
        }

        private Func<bool> chaseCrowded;

        // Call every tick, even while in range, so the target's speed is known when it runs off.
        public Vector3 WatchChase(Vector3 dest)
        {
            return chaseLead.Lead(dest, Seconds(DateTime.Now), Math.Max(1.0f, EffectiveSpeed(MOVE_STATE_RUN) * 1.5f));
        }

        private bool planningChase;

        private bool ChaseLed(Vector3 dest, Vector3 led, ushort moveState, float stopShort)
        {
            planningChase = true;
            try
            {
                return ChaseLedPlanned(dest, led, moveState, stopShort);
            }
            finally
            {
                planningChase = false;
            }
        }

        private bool ChaseLedPlanned(Vector3 dest, Vector3 led, ushort moveState, float stopShort)
        {
            DateTime now = DateTime.Now;
            if (chaseLead.Moving && (now - leadFailedAt).TotalSeconds >= FAILED_REPATH_INTERVAL)
            {
                // Keep the lead short of walls: past one, the route fails and the mob stops and starts every tick.
                Vector3 ahead = led;
                float want = MoverMath.XZDistance(dest, ahead);
                float clear = NavmeshUtils.ClearanceTowards(owner.CurrentArea, dest, ahead);
                if (clear < want)
                {
                    float k = Math.Max(0.0f, clear - 0.5f) / want;
                    ahead = new Vector3(dest.X + (ahead.X - dest.X) * k, dest.Y, dest.Z + (ahead.Z - dest.Z) * k);
                }
                if (MoverMath.XZDistance(dest, ahead) > repathDistance)
                {
                    if (MoveTo(ahead, moveState, stopShort))
                    {
                        chasing = true;
                        return true;
                    }
                    if (LastOutcome == Outcome.NoRoute || LastOutcome == Outcome.Partial)
                        leadFailedAt = now;
                }
            }
            bool moving = MoveTo(dest, moveState, stopShort);
            chasing = true;
            return moving;
        }

        public void Stop()
        {
            ClearRoute();
            LastOutcome = Outcome.Stopped;
            pendingStop = false;
            if (ownsState && owner.moveState != MOVE_STATE_STOP)
                StopInPlace();
            ownsState = false;
            EndCadence();
        }

        // Sent as 0x00CE so the client places the actor instead of running it there.
        public void Teleport(Vector3 pos, float rotation)
        {
            if (pos == null || owner.CurrentArea == null)
                return;
            ClearRoute();
            LastOutcome = Outcome.None;
            pendingStop = false;
            floor.Reset();
            Reposition(pos, rotation);
        }

        private void Reposition(Vector3 pos, float rotation)
        {
            EndCadence();
            owner.ClearPositionUpdates();
            owner.oldPositionX = owner.positionX;
            owner.oldPositionY = owner.positionY;
            owner.oldPositionZ = owner.positionZ;
            owner.oldRotation = owner.rotation;
            owner.positionX = pos.X;
            owner.positionY = pos.Y;
            owner.positionZ = pos.Z;
            owner.rotation = rotation;
            owner.moveState = MOVE_STATE_STOP;
            owner.CurrentArea.UpdateActorPosition(owner);
            owner.CurrentArea.BroadcastPacketAroundActor(owner,
                SetActorPositionPacket.BuildPacket(owner.Id, owner.Id, pos.X, pos.Y, pos.Z, rotation, 0, false));
        }

        #endregion

        #region Tick

        // Dead, or despawning (the despawn clears the death state before the actor leaves).
        private bool IsCorpse()
        {
            return owner.IsDead() || (owner is BattleNpc && owner.GetHP() <= 0);
        }

        public void Update(DateTime tick)
        {
            if (LastOutcome == Outcome.Moving && IsCorpse())
                Stop();
            if (LastOutcome != Outcome.Moving)
            {
                if (pendingStop)
                {
                    // Like retail, the stop goes out a moment after the client arrives.
                    if (cadence.Active && Seconds(tick) < stopAt)
                        return;
                    pendingStop = false;
                    if (owner.moveState != MOVE_STATE_STOP)
                        StopInPlace();
                    ownsState = false;
                    EndCadence();
                }
                return;
            }

            double dt = lastTick == DateTime.MinValue ? NOMINAL_DT : (tick - lastTick).TotalSeconds;
            if (dt <= 0.0 || dt > 1.0)
                dt = NOMINAL_DT;
            dt = Math.Min(MAX_DT, dt);
            lastTick = tick;

            if (owner.aiContainer == null || !owner.aiContainer.CanFollowPath())
            {
                // Asleep, bound or casting: keep the route and wait, without counting it as stuck.
                if (owner.moveState != MOVE_STATE_STOP)
                    StopInPlace();
                EndCadence();
                ResetStuck(tick, owner.GetPosAsVector3());
                return;
            }

            if (!needPlan && routeGoal != null && goal != null && Utils.Distance(goal, routeGoal) > repathDistance
                && (tick - lastPlan).TotalSeconds >= REPATH_INTERVAL)
                needPlan = true;
            if (!needPlan && navRoute != null && navRoute.Stale)
                needPlan = true;    // a gate in this area opened or closed

            if (needPlan)
            {
                needPlan = false;
                if (!Plan(tick))
                    return;
            }

            Vector3 pos = owner.GetPosAsVector3();
            // The actor starts with the client, when the first 0x00CF goes out.
            float budget = 0.0f;
            if (cadence.Active)
            {
                double walked = Seconds(tick) - cadence.WalkStart;
                budget = MoveCadence.Step(EffectiveSpeed(state), walked - dt, walked);
            }
            // While blocked, the client stops at the last target it got.
            if (cadence.Active && !double.IsNaN(blockedSince))
                budget = Math.Min(budget, MoverMath.XZDistance(pos, cadence.Target));
            Vector3 next = MoverMath.Advance(pos, route, ref routeIndex, budget, out float travelled);

            if (travelled > 0.001f)
            {
                owner.LookAt(next);
                owner.OnPath(next);
            }
            owner.moveState = state;
            ownsState = true;
            owner.ClearPositionUpdates();
            owner.QueuePositionUpdate(next);
            TrackFloor(next);
            stuckExpected += budget;

            bool done = routeIndex >= route.Count && !routeTruncated;
            ScheduleHop(tick, next, done);

            if (routeIndex >= route.Count)
            {
                if (routeTruncated)
                    needPlan = true;    // long trip: plan the next part next tick
                else
                {
                    Finish(routePartial ? Outcome.Partial : Outcome.Arrived, holdOnArrive);
                    return;
                }
            }

            CheckStuck(tick, next);
        }

        #endregion

        #region Internals

        private bool Plan(DateTime now)
        {
            lastPlan = now;
            routeGoal = goal;
            route.Clear();
            routeIndex = 1;
            routePartial = false;
            routeTruncated = false;
            needPlan = false;

            if (!ignoreNav && failedGoal != null && (now - failedAt).TotalSeconds < FAILED_REPATH_INTERVAL && Utils.Distance(failedGoal, goal) <= repathDistance)
            {
                StopMotion(failedOutcome);
                return false;
            }

            Vector3 pos = owner.GetPosAsVector3();
            List<Vector3> points;
            PathResult result;
            bool more = false;
            var instance = ignoreNav ? null : NavmeshUtils.GetNavInstance(owner.CurrentArea);
            if (ignoreNav)
            {
                navRoute = null;
                points = new List<Vector3>(1) { goal };
                result = PathResult.NoMesh;
            }
            else if (instance != null)
                points = PlanOnNavWorld(instance, pos, out result, out more);
            else
            {
                navRoute = null;
                points = NavmeshUtils.GetPath(owner.CurrentArea, pos, goal, out result, ROUTE_STEP, ROUTE_MAX_POINTS);
            }
            LastPathResult = result;

            if (points == null || points.Count == 0)
            {
                if (result == PathResult.SamePoint)
                {
                    Finish(Outcome.Arrived, false);
                    return false;
                }
                Fail(Outcome.NoRoute, now);
                return false;
            }

            route.Add(GroundUnder(pos));
            route.AddRange(points);
            routeTruncated = more || (instance == null && result != PathResult.NoMesh && points.Count >= ROUTE_MAX_POINTS);

            float gap = MoverMath.XZDistance(route[route.Count - 1], goal);
            routePartial = result == PathResult.Partial && gap > stopShort + PARTIAL_SLACK;
            if (!routeTruncated && stopShort > gap)
                MoverMath.TrimEnd(route, stopShort - gap);

            if (route.Count <= 1 || (!routeTruncated && MoverMath.PathLength(route) < 0.05f))
            {
                if (routePartial)
                    Fail(Outcome.Partial, now);
                else
                    Finish(Outcome.Arrived, false);
                return false;
            }

            BeginMoving(now);
            return true;
        }

        private const float CHASE_GOAL_VERTICAL = 12.0f, CHASE_GOAL_ABOVE = 2.0f;

        private List<Vector3> PlanOnNavWorld(Meteor.Navigation.NavInstance instance, Vector3 pos, out PathResult result, out bool more)
        {
            var from = NavInstanceMesh.N(pos);
            var agent = NavmeshUtils.AgentFor(owner);
            var start = floor.Track(instance, agent, from);
            var opts = new Meteor.Navigation.RouteOpts { SampleStep = ROUTE_STEP };
            bool resume = navRoute != null && navRoute.Instance == instance && !navRoute.Complete && !navRoute.Stale
                && MoverMath.XZDistance(NavInstanceMesh.M(navRoute.Target), goal) <= repathDistance;
            if (resume)
                navRoute.Advance(start, from);
            else
                navRoute = instance.PlanRoute(start, from, NavInstanceMesh.N(goal), agent, opts);
            if ((chasing || planningChase) && navRoute.Reason == Meteor.Navigation.NavReason.VerticalMismatch)
            {
                // The target is off the mesh (on a rock): chase to the ground under it instead of stopping.
                var ground = instance.Project(NavInstanceMesh.N(goal), NavmeshUtils.AgentFor(owner), CHASE_GOAL_VERTICAL);
                // Not ground far above: for a target in a tunnel, that is the tunnel's roof.
                float rise = ground.Ok ? ground.Position.Y - goal.Y : float.NaN;
                if (ground.Ok && rise <= CHASE_GOAL_ABOVE && rise >= -CHASE_GOAL_VERTICAL)
                    navRoute = instance.PlanRoute(start, from, ground.Position, agent, opts);
            }

            result = NavInstanceMesh.ToPathResult(navRoute.Reason);
            more = navRoute.Ok && !navRoute.Complete;
            if (!navRoute.Ok)
                return null;
            var points = new List<Vector3>(navRoute.Points.Count);
            foreach (var p in navRoute.Points)
                points.Add(NavInstanceMesh.M(p));
            return points;
        }

        private void TrackFloor(Vector3 pos)
        {
            var instance = NavmeshUtils.GetNavInstance(owner.CurrentArea);
            if (instance != null)
                floor.Track(instance, NavmeshUtils.AgentFor(owner), NavInstanceMesh.N(pos));
        }

        private void BeginMoving(DateTime now)
        {
            if (LastOutcome != Outcome.Moving)
            {
                ResetStuck(now, owner.GetPosAsVector3());
                stuckRepathed = false;
                // Otherwise the first step would cover the whole time spent standing.
                lastTick = DateTime.MinValue;
            }
            failedGoal = null;
            pendingStop = false;
            LastOutcome = Outcome.Moving;
        }

        private Vector3 GroundUnder(Vector3 pos)
        {
            var navMesh = NavmeshUtils.GetNavMesh(owner.CurrentArea);
            if (navMesh != null && navMesh.TryProject(pos, out var ground) && MoverMath.XZDistance(ground, pos) < 1.0f)
                return new Vector3(pos.X, ground.Y, pos.Z);
            return new Vector3(pos.X, pos.Y, pos.Z);
        }

        private void Finish(Outcome outcome, bool hold)
        {
            route.Clear();
            routeIndex = 0;
            LastOutcome = outcome;
            pendingStop = !hold;
            if (!hold)
                stopAt = Math.Max(cadence.ArrivesAt(), Seconds(DateTime.Now)) + MoveCadence.STOP_DELAY;
            if (hold)
                ownsState = true;
            var cb = onDone;
            onDone = null;
            cb?.Invoke(outcome);
        }

        private void Fail(Outcome outcome, DateTime now)
        {
            failedGoal = goal;
            failedAt = now;
            failedOutcome = outcome;
            StopMotion(outcome);
        }

        private void StopMotion(Outcome outcome)
        {
            route.Clear();
            routeIndex = 0;
            LastOutcome = outcome;
            pendingStop = false;
            if (ownsState && owner.moveState != MOVE_STATE_STOP)
                StopInPlace();
            ownsState = false;
            EndCadence();
            var cb = onDone;
            onDone = null;
            cb?.Invoke(outcome);
        }

        private void ClearRoute()
        {
            navRoute = null;
            route.Clear();
            routeIndex = 0;
            goal = null;
            routeGoal = null;
            needPlan = false;
            Scripted = false;
            chaseLead.Rebase();
            chasing = false;
            onDone = null;
        }

        private void ResetStuck(DateTime tick, Vector3 pos)
        {
            stuckSince = tick;
            stuckPos = pos;
            stuckExpected = 0.0f;
        }

        // Under 10% of the expected progress in 2 s: plan again once, then give up as Stuck.
        private void CheckStuck(DateTime tick, Vector3 next)
        {
            if (stuckPos == null)
            {
                ResetStuck(tick, next);
                return;
            }
            if ((tick - stuckSince).TotalSeconds < STUCK_WINDOW_SECONDS)
                return;
            bool stuck = stuckExpected > 0.5f && MoverMath.XZDistance(stuckPos, next) < STUCK_PROGRESS * stuckExpected;
            ResetStuck(tick, next);
            if (!stuck)
            {
                stuckRepathed = false;
                return;
            }
            if (!stuckRepathed)
            {
                stuckRepathed = true;
                needPlan = true;
                return;
            }
            stuckRepathed = false;
            Fail(Outcome.Stuck, tick);
        }

        private float EffectiveSpeed(ushort moveState)
        {
            if (moveState >= owner.moveSpeeds.Length)
                return 0.0f;
            return owner.moveSpeeds[moveState];
        }

        #endregion

        #region Hop cadence

        private static double Seconds(DateTime t) => t.Ticks / (double)TimeSpan.TicksPerSecond;

        private void ScheduleHop(DateTime tick, Vector3 next, bool done)
        {
            float speed = EffectiveSpeed(state);
            double now = Seconds(tick);
            owner.cadenceHold = true;

            var chord = ChordCheck();
            cadence.HoldHop = chasing ? chaseCrowded : null;
            var hop = cadence.Plan(now, next, route, routeIndex, done, routeTruncated, speed, state,
                state == MOVE_STATE_WALK, NOMINAL_DT, float.NaN, LineClear,
                chasing ? MoveCadence.FOLLOW_RESEND : 0.0, ChordEnforced ? chord : null);
            AfterHop(tick, hop, chord);
        }

        // A blocked hop waits a tick, then plans again, then tries a recovery hop, then gives up as Stuck.
        private void AfterHop(DateTime tick, MoveCadence.Hop hop, Func<Vector3, Vector3, ChordResult> chord)
        {
            if (hop.Send && !hop.Checked && chord != null)
            {
                hop.Check = chord(owner.GetPosAsVector3(), hop.Target);
                hop.FirstFail = hop.Check;
                hop.Checked = true;
            }
            if (hop.Send)
            {
                Ask(hop.Target);
                ClearBlocked();
                return;
            }
            if (!hop.Blocked)
                return;
            double now = Seconds(tick);
            if (double.IsNaN(blockedSince))
                blockedSince = now;
            else if (!blockedReplanned)
            {
                blockedReplanned = true;
                needPlan = true;
            }
            else if (blockedRecoveries < MAX_RECOVERIES && Recover(tick))
                blockedRecoveries++;
            else if (now - blockedSince >= BLOCKED_GIVE_UP)
            {
                Program.Log.Debug("{0} ({1:X}): no safe hop for {2:F1} s ({3}), stuck.", owner.Name, owner.Id, now - blockedSince, hop.Check);
                ClearBlocked();
                Fail(Outcome.Stuck, tick);
            }
        }

        private void StopInPlace()
        {
            owner.moveState = MOVE_STATE_STOP;
            owner.updateFlags |= ActorUpdateFlags.Position;
        }

        private void ClearBlocked()
        {
            blockedSince = double.NaN;
            blockedReplanned = false;
            blockedRecoveries = 0;
        }

        // A short hop out of a notch in the mesh edge, from which the walk can go on.
        private bool Recover(DateTime tick)
        {
            var c = owner.GetPosAsVector3();
            if (owner.CurrentArea == null || route.Count == 0)
                return false;
            float speed = EffectiveSpeed(state);
            int ri = Math.Min(routeIndex, route.Count - 1);
            var ahead = MoverMath.Advance(owner.GetPosAsVector3(), route, ref ri, MoveCadence.MaxHop(speed, state == MOVE_STATE_WALK), out _);
            var world = new AreaChordWorld(owner.CurrentArea, NavmeshUtils.AgentFor(owner));
            if (!ChordValidator.Recover(world, new System.Numerics.Vector3(c.X, c.Y, c.Z),
                    new System.Numerics.Vector3(ahead.X, ahead.Y, ahead.Z), speed, 0.0f, out var q))
                return false;
            var target = new Vector3(q.X, q.Y, q.Z);
            Program.Log.Debug("{0} ({1:X}): no hop toward ({2:F1}, {3:F1}) passes, recovery hop to ({4:F2}, {5:F2}, {6:F2}).",
                owner.Name, owner.Id, ahead.X, ahead.Z, target.X, target.Y, target.Z);
            cadence.Sent(c, target, speed, state, Seconds(tick), false);
            Ask(target);
            return true;
        }

        private static bool ChordEnforced => ConfigConstants.CHORD_VALIDATOR == ConfigConstants.ChordMode.On;

        // Null when chord_validator is off.
        private Func<Vector3, Vector3, ChordResult> ChordCheck()
        {
            if (ConfigConstants.CHORD_VALIDATOR == ConfigConstants.ChordMode.Off || owner.CurrentArea == null)
                return null;
            var world = new AreaChordWorld(owner.CurrentArea, NavmeshUtils.AgentFor(owner));
            float speed = EffectiveSpeed(state);
            return (c, t) => ChordValidator.Check(world, new System.Numerics.Vector3(c.X, c.Y, c.Z),
                new System.Numerics.Vector3(t.X, t.Y, t.Z), speed, 0.0f);
        }

        private void Ask(Vector3 target)
        {
            owner.cadenceTarget = GroundUnder(target);
            owner.cadenceRot = MoveCadence.Yaw(cadence.From, target, owner.rotation);
            owner.updateFlags |= ActorUpdateFlags.Position;
        }

        private bool LineClear(Vector3 from, Vector3 to)
        {
            return NavmeshUtils.ClearanceTowards(owner.CurrentArea, from, to) >= MoverMath.XZDistance(from, to) - 0.05f;
        }

        private void EndCadence()
        {
            ClearBlocked();
            cadence.Reset();
            owner.cadenceHold = false;
            owner.cadenceTarget = null;
            stopAt = double.NaN;
        }

        #endregion

        public string Describe()
        {
            if (LastOutcome != Outcome.Moving)
                return $"{LastOutcome} (last path {LastPathResult}), {floor}";
            return $"moving to ({goal?.X:F1}, {goal?.Y:F1}, {goal?.Z:F1}) state {state}, {Math.Max(0, route.Count - routeIndex)} points left, " +
                   (cadence.Active ? $"hop to ({cadence.Target.X:F1}, {cadence.Target.Z:F1}){(cadence.Final ? " final" : "")}, " : "") +
                   $"{MoverMath.PathLength(route, Math.Max(0, routeIndex - 1)):F1}y, speed {EffectiveSpeed(state):F2}" +
                   (navRoute != null ? $", nav {navRoute.Agent} {navRoute}" : "") + $", {floor}";
        }
    }
}
