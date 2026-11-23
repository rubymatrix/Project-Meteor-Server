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
using Meteor.Map.packets.send.actor;
using Meteor.Map.actors.area;
using Meteor.Map.utils;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.actors.chara.npc;

namespace Meteor.Map.actors.chara.ai.controllers
{
    class BattleNpcController : Controller
    {
        protected DateTime lastActionTime;
        protected DateTime lastSpellCastTime;
        protected DateTime lastSkillTime;
        protected DateTime lastSpecialSkillTime; // todo: i dont think monsters have "2hr" cooldowns like ffxi
        protected DateTime deaggroTime;
        protected DateTime neutralTime;
        protected DateTime waitTime;

        private bool firstSpell = true;
        protected DateTime lastRoamUpdate;
        protected DateTime battleStartTime;

        protected new BattleNpc owner;
        public BattleNpcController(BattleNpc owner) :
            base(owner)
        {
            this.owner = owner;
            this.lastUpdate = GameClock.Now;
            this.waitTime = lastUpdate.AddSeconds(5);
        }

        public override void Update(DateTime tick)
        {
            lastUpdate = tick;
            if (!owner.IsDead())
            {
                // todo: handle aggro/deaggro and other shit here
                if (!owner.aiContainer.IsEngaged())
                {
                    TryAggro(tick);
                }

                if (owner.aiContainer.IsEngaged())
                {
                    DoCombatTick(tick);
                }
                //Only move if owner isn't dead and is either too far away from their spawn point or is meant to roam and isn't in combat
                else if (!owner.IsDead() && (owner.isMovingToSpawn || owner.GetMobMod((uint)MobModifier.Roams) > 0))
                {
                    DoRoamTick(tick);
                }
            }
        }

        public bool TryDeaggro()
        {
            string reason = null;
            if (owner.hateContainer.GetMostHatedTarget() == null)
                reason = "noHate";
            else if (!owner.aiContainer.GetTargetFind().CanTarget(owner.target as Character))
                reason = "cannotTarget";
            else if (!owner.IsCloseToSpawn())
                reason = "leash";
            if (reason != null && Telemetry.On)
                Telemetry.Emit("ai.deaggro", owner.Id, owner.target?.Id ?? 0, ("reason", reason));
            return reason != null;
        }

        //If the owner isn't moving to spawn, iterate over nearby enemies and 
        //aggro the first one that is within 10 levels and can be detected, then engage
        protected virtual void TryAggro(DateTime tick)
        {
            if (tick >= neutralTime && !owner.isMovingToSpawn)
            {
                if (!owner.neutral && owner.IsAlive())
                {
                    foreach (var chara in owner.CurrentArea.GetActorsAroundActor<Character>(owner, 50))
                    {
                        if (chara.allegiance == owner.allegiance)
                           continue;

                        if (owner.detectionType != DetectionType.None)
                        {
                            uint levelDifference = (uint)Math.Abs(owner.GetLevel() - chara.GetLevel());

                            if (levelDifference <= 10 || (owner.detectionType & DetectionType.IgnoreLevelDifference) != 0 && CanAggroTarget(chara))
                            {
                                owner.hateContainer.AddBaseHate(chara);
                                break;
                            }
                        }
                    }
                }
            }

            if (owner.hateContainer.GetHateList().Count > 0)
            {
                Engage(owner.hateContainer.GetMostHatedTarget());
            }
        }

        public override bool Engage(Character target)
        {
            var canEngage = this.owner.aiContainer.InternalEngage(target);
            if (canEngage)
            {
                //owner.ChangeState(SetActorStatePacket.MAIN_STATE_ACTIVE);

                // reset casting
                firstSpell = true;
                // todo: find a better place to put this?
                if (owner.GetState() != SetActorStatePacket.MAIN_STATE_ACTIVE)
                    owner.ChangeState(SetActorStatePacket.MAIN_STATE_ACTIVE);

                lastActionTime = GameClock.Now;
                battleStartTime = lastActionTime;
                // todo: adjust cooldowns with modifiers
            }
            return canEngage;
        }

        protected bool TryEngage(Character target)
        {
            // todo:
            return true;
        }

        public override void Disengage()
        {
            var target = owner.target;
            base.Disengage();
            // todo:
            lastActionTime = lastUpdate.AddSeconds(5);
            // A despawn clears the death state before it disengages, so HP tells a corpse apart.
            if (owner.IsDead() || owner.GetHP() <= 0)
                owner.aiContainer.mover.Stop();
            else
            {
                owner.isMovingToSpawn = true;
                owner.aiContainer.mover.MoveTo(new Vector3(owner.spawnX, owner.spawnY, owner.spawnZ), Mover.MOVE_STATE_RUN);
            }
            neutralTime = lastActionTime;
            owner.hateContainer.ClearHate();
            lua.LuaEngine.CallLuaBattleFunction(owner, "onDisengage", owner, target, Utils.UnixTimeStampUTC(lastUpdate));
        }

        public override void Cast(Character target, uint spellId)
        {
            // todo:
            if(owner.aiContainer.CanChangeState())
                owner.aiContainer.InternalCast(target, spellId);
        }

        public override void Ability(Character target, uint abilityId)
        {
            // todo:
            if (owner.aiContainer.CanChangeState())
                owner.aiContainer.InternalAbility(target, abilityId);
        }

        public override void RangedAttack(Character target)
        {
            // todo:
        }

        public override void MonsterSkill(Character target, uint mobSkillId)
        {
            // todo:
        }

        protected virtual void DoRoamTick(DateTime tick, List<Character> contentGroupCharas = null)
        {
            var mover = owner.aiContainer.mover;
            if (tick >= waitTime)
            {
                neutralTime = tick.AddSeconds(5);
                if (mover.IsMoving)
                    lastActionTime = tick.AddSeconds(-5);
                waitTime = tick.AddSeconds(owner.GetMobMod((uint) MobModifier.RoamDelay));
                owner.OnRoam(tick);

                if (CanMoveForward(0.0f) && !mover.IsMoving && owner.aiContainer.CanFollowPath())
                {
                    var dest = owner.FindRandomPoint(owner.spawnX, owner.spawnY, owner.spawnZ, 1.5f, 50.0f);
                    mover.MoveTo(dest, owner.isMovingToSpawn ? Mover.MOVE_STATE_RUN : Mover.MOVE_STATE_WALK);
                }
                //lua.LuaEngine.CallLuaBattleFunction(owner, "onRoam", owner, contentGroupCharas);
            }
        }

        protected virtual void DoCombatTick(DateTime tick, List<Character> contentGroupCharas = null)
        {
            HandleHate();
            // todo: magic/attack/ws cooldowns etc
            if (TryDeaggro())
            {
                Disengage();
                return;
            }
            owner.SetMod((uint)Modifier.MovementSpeed, 5);
            Move();
            if ((tick - lastCombatTickScript).TotalSeconds > 3)
            {
                //if (owner.aiContainer.CanChangeState())
                    //owner.aiContainer.WeaponSkill(owner.zone.FindActorInArea<Character>(owner.target.actorId), 27155);
                //lua.LuaEngine.CallLuaBattleFunction(owner, "onCombatTick", owner, owner.target, Utils.UnixTimeStampUTC(tick), contentGroupCharas);
                lastCombatTickScript = tick;
            }
        }

        protected virtual void Move()
        {
            var mover = owner.aiContainer.mover;
            if (owner.target == null || !owner.aiContainer.CanFollowPath() || mover.Scripted)
                return;

            if (owner.statusEffects.HasStatusEffectsByFlag(StatusEffectFlags.PreventMovement))
            {
                mover.Stop();
                return;
            }

            var myPos = owner.GetPosAsVector3();
            var targetPos = owner.target.GetPosAsVector3();
            var distance = Utils.Distance(myPos, targetPos);
            float stopDistance = StopDistance(owner);
            mover.WatchChase(targetPos);

            // Several mobs on one standing target: each goes to its own stop around it.
            if (!(owner is Ally) && !mover.ChaseTargetMoving && owner.target is Character spreadTarget
                && SpreadStop(spreadTarget, myPos, targetPos) is Vector3 stop)
            {
                float toStop = MoverMath.XZDistance(myPos, stop);
                bool inRange = distance <= stopDistance;
                if (toStop <= SPREAD_ARRIVE || (inRange && !mover.IsMoving && toStop <= SPREAD_KEEP))
                {
                    mover.Stop();
                    FaceTarget();
                    return;
                }
                if (inRange && !mover.IsMoving)
                {
                    // Stepping aside for a mob that arrived next to it: one step at a time.
                    if ((GameClock.Now - lastSpreadStep).TotalSeconds < SPREAD_STEP_SECONDS)
                    {
                        mover.Stop();
                        FaceTarget();
                        return;
                    }
                    lastSpreadStep = GameClock.Now;
                }
                if (!mover.MoveTo(stop, Mover.MOVE_STATE_RUN, 0.0f))
                    FaceTarget();
                lastRoamUpdate = GameClock.Now;
                return;
            }
            spreadStop = null;

            if (distance <= stopDistance || !CanMoveForward(distance))
            {
                mover.Stop();
                FaceTarget();
                return;
            }

            // Route to the target, not to a point short of it: that point can be on the far side of a thin wall.
            if (!mover.Chase(targetPos, Mover.MOVE_STATE_RUN, stopDistance))
                FaceTarget();
            lastRoamUpdate = GameClock.Now;
        }

        private static float StopDistance(Character mob)
        {
            return Math.Max(0.0f, mob.GetAttackRange() - 0.2f);
        }

        // One solution per target per tick, shared by every mob on it, so none chases another's old stop.
        private sealed class SpreadSolution
        {
            public DateTime At;
            public Dictionary<uint, MeleeSpread.Stop> Stops;
        }
        private static readonly Dictionary<uint, SpreadSolution> spreads = new Dictionary<uint, SpreadSolution>();
        // Mobs this far past their stop distance from the target count as gathering on it.
        private const float SPREAD_GROUP_RANGE = 8.0f;
        private const double SPREAD_FRESH_SECONDS = 0.25;
        private const float SPREAD_ARRIVE = 0.4f, SPREAD_KEEP = 0.4f;
        private const double SPREAD_STEP_SECONDS = 2.0;
        private const float SPREAD_TRY_STEP = 5.0f * (float)Math.PI / 180.0f;
        private const float MOB_BODY = 0.5f;
        private Vector3 spreadStop;
        private DateTime lastSpreadStep = DateTime.MinValue;

        // This mob's stop around a standing target, or null when it fights it alone (it stops on its
        // approach line) or no stop near its spread bearing is usable.
        private Vector3 SpreadStop(Character target, Vector3 myPos, Vector3 targetPos)
        {
            MeleeSpread.Stop mine;
            lock (spreads)
            {
                DateTime now = GameClock.Now;
                if (!spreads.TryGetValue(target.Id, out var sol) || (now - sol.At).TotalSeconds > SPREAD_FRESH_SECONDS || !sol.Stops.ContainsKey(owner.Id))
                {
                    sol = new SpreadSolution { At = now, Stops = new Dictionary<uint, MeleeSpread.Stop>() };
                    var group = SpreadGroup(target);
                    if (group.Count >= 2)
                    {
                        var members = new List<MeleeSpread.Member>();
                        foreach (var bn in group)
                            members.Add(new MeleeSpread.Member
                            {
                                Id = bn.Id,
                                X = bn.positionX,
                                Z = bn.positionZ,
                                Radius = StopDistance(bn),
                                MaxRadius = StopDistance(bn),
                                Body = MOB_BODY,
                                Standing = !bn.aiContainer.mover.IsMoving,
                            });
                        foreach (var st in MeleeSpread.Solve(targetPos.X, targetPos.Z, members))
                            sol.Stops[st.Id] = st;
                    }
                    spreads[target.Id] = sol;
                    if (spreads.Count > 256)
                    {
                        var stale = new List<uint>();
                        foreach (var kv in spreads)
                            if ((now - kv.Value.At).TotalSeconds > 5)
                                stale.Add(kv.Key);
                        foreach (var id in stale)
                            spreads.Remove(id);
                    }
                }
                if (!sol.Stops.TryGetValue(owner.Id, out mine))
                {
                    spreadStop = null;
                    return null;
                }
            }

            var stop = UsableStop(mine, myPos, targetPos);
            if (stop == null)
            {
                spreadStop = null;
                return null;
            }
            if (spreadStop != null && MoverMath.XZDistance(spreadStop, stop) <= SPREAD_KEEP)
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
        // nearest bearing back toward the approach line that is, in 5 degree steps; null when none is.
        private Vector3 UsableStop(MeleeSpread.Stop s, Vector3 myPos, Vector3 targetPos)
        {
            var navMesh = NavmeshUtils.GetNavMesh(owner.CurrentArea);
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
                if (NavmeshUtils.ClearanceTowards(owner.CurrentArea, targetPos, ground) < reach - 0.05f)
                    continue;
                if (!navMesh.IsReachable(myPos, ground))
                    continue;
                return ground;
            }
            return null;
        }

        protected void FaceTarget()
        {
            // todo: check if stunned etc
            if (owner.statusEffects.HasStatusEffectsByFlag(StatusEffectFlags.PreventTurn) )
            {
            }
            else
            {
                owner.LookAt(owner.target);
            }
        }

        protected bool CanMoveForward(float distance)
        {
            // todo: check spawn leash and stuff
            if (!owner.IsCloseToSpawn())
            {
                return false;
            }
            if (owner.GetSpeed() == 0)
            {
                return false;
            }
            return true;
        }

        public virtual bool CanAggroTarget(Character target)
        {
            if (owner.neutral || owner.detectionType == DetectionType.None || owner.IsDead())
            {
                return false;
            }

            // todo: can mobs aggro mounted targets?
            if (target.IsDead() || target.currentMainState == SetActorStatePacket.MAIN_STATE_MOUNTED)
            {
                return false;
            }

            if (owner.aiContainer.IsSpawned() && !owner.aiContainer.IsEngaged() && CanDetectTarget(target))
            {
                return true;
            }
            return false;
        }

        public virtual bool CanDetectTarget(Character target, bool forceSight = false)
        {
            if (owner.IsDead())
                return false;

            // todo: this should probably be changed to only allow detection at end of path?
            if (owner.aiContainer.mover.Scripted)
            {
                return false;
            }

            // todo: handle sight/scent/hp etc
            if (target.IsDead() || target.currentMainState == SetActorStatePacket.MAIN_STATE_MOUNTED)
                return false;

            float verticalDistance = Math.Abs(target.positionY - owner.positionY);
            if (verticalDistance > 8)
                return false;

            var distance = Utils.Distance(owner.positionX, owner.positionY, owner.positionZ, target.positionX, target.positionY, target.positionZ);

            bool detectSight = forceSight || (owner.detectionType & DetectionType.Sight) != 0;
            bool hasSneak = false;
            bool hasInvisible = false;
            bool isFacing = owner.IsFacing(target);

            // use the mobmod sight range before defaulting to 20 yalms
            if (detectSight && !hasInvisible && isFacing && distance < owner.GetMobMod((uint)MobModifier.SightRange))
                return CanSeePoint(target.positionX, target.positionY, target.positionZ);

            // todo: check line of sight and aggroTypes
            if (distance > 20)
            {
                return false;
            }

            // todo: seems ffxiv doesnt even differentiate between sneak/invis?
            {
                hasSneak = target.GetMod(Modifier.Stealth) > 0;
                hasInvisible = hasSneak;
            }



            if ((owner.detectionType & DetectionType.Sound) != 0 && !hasSneak && distance < owner.GetMobMod((uint)MobModifier.SoundRange))
                return CanSeePoint(target.positionX, target.positionY, target.positionZ);

            if ((owner.detectionType & DetectionType.Magic) != 0 && target.aiContainer.IsCurrentState<MagicState>())
                return CanSeePoint(target.positionX, target.positionY, target.positionZ);

            if ((owner.detectionType & DetectionType.LowHp) != 0 && target.GetHPP() < 75)
                return CanSeePoint(target.positionX, target.positionY, target.positionZ);

            return false;
        }

        public virtual bool CanSeePoint(float x, float y, float z)
        {
            return NavmeshUtils.CanSee(owner.CurrentArea, owner.positionX, owner.positionY, owner.positionZ, x, y, z);
        }

        protected virtual void HandleHate()
        {
            ChangeTarget(owner.hateContainer.GetMostHatedTarget());
        }

        public override void ChangeTarget(Character target)
        {
            if (target != owner.target)
            {
                if (Telemetry.On)
                    Telemetry.Emit("ai.target", owner.Id, target?.Id ?? 0, ("from", owner.target?.Id ?? 0), ("rule", "topEnmity"));
                owner.target = target;
                owner.currentLockedTarget = target?.Id ?? Actor.INVALID_ACTORID;
                owner.currentTarget = target?.Id ?? Actor.INVALID_ACTORID;

                 foreach (var player in owner.CurrentArea.GetActorsAroundActor<Player>(owner, 50))
                    player.QueuePacket(owner.GetHateTypePacket(player));

                base.ChangeTarget(target);

                owner.UpdateEnmityIndicator(target);
            }
        }
    }
}
