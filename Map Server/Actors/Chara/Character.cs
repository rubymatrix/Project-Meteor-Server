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


using Meteor.Common;
using Meteor.Map.actors.chara.player;
using Meteor.Map.actors.group;
using Meteor.Map.Actors.Chara;
using Meteor.Map.DataObjects;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.inventory;
using Meteor.Map.utils;
using Meteor.Map.actors.chara.ai;
using System;
using System.Collections.Generic;
using Meteor.Map.actors.chara;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.AI;
using Meteor.Map.Content;

namespace Meteor.Map.Actors
{
    enum DamageTakenType
    {
        None,
        Attack,
        Magic,
        Weaponskill,
        Ability
    }

    class Character : Actor
    {
        public const int CLASSID_PUG = 2;
        public const int CLASSID_GLA = 3;
        public const int CLASSID_MRD = 4;
        public const int CLASSID_ARC = 7;
        public const int CLASSID_LNC = 8;
        public const int CLASSID_THM = 22;
        public const int CLASSID_CNJ = 23;

        public const int CLASSID_CRP = 29;
        public const int CLASSID_BSM = 30;
        public const int CLASSID_ARM = 31;
        public const int CLASSID_GSM = 32;
        public const int CLASSID_LTW = 33;
        public const int CLASSID_WVR = 34;
        public const int CLASSID_ALC = 35;
        public const int CLASSID_CUL = 36;

        public const int CLASSID_MIN = 39;
        public const int CLASSID_BTN = 40;
        public const int CLASSID_FSH = 41;

        public const int SIZE = 0;
        public const int COLORINFO = 1;
        public const int FACEINFO = 2;
        public const int HIGHLIGHT_HAIR = 3;
        public const int VOICE = 4;
        public const int MAINHAND = 5;
        public const int OFFHAND = 6;
        public const int SPMAINHAND = 7;
        public const int SPOFFHAND = 8;
        public const int THROWING = 9;
        public const int PACK = 10;
        public const int POUCH = 11;
        public const int HEADGEAR = 12;
        public const int BODYGEAR = 13;
        public const int LEGSGEAR = 14;
        public const int HANDSGEAR = 15;
        public const int FEETGEAR = 16;
        public const int WAISTGEAR = 17;
        public const int NECKGEAR = 18;
        public const int L_EAR = 19;
        public const int R_EAR = 20;
        public const int R_WRIST = 21;
        public const int L_WRIST = 22;
        public const int R_RINGFINGER = 23;
        public const int L_RINGFINGER = 24;
        public const int R_INDEXFINGER = 25;
        public const int L_INDEXFINGER = 26;
        public const int UNKNOWN = 27;

        public bool isStatic = false;

        public bool isMovingToSpawn = false;
        public bool isAutoAttackEnabled = true;

        public uint modelId;
        public uint[] appearanceIds = new uint[28];

        public uint animationId = 0;

        public uint currentTarget = Actor.INVALID_ACTORID;
        public uint currentLockedTarget = Actor.INVALID_ACTORID;

        public uint currentActorIcon = 0;

        public Work work = new Work();
        public CharaWork charaWork = new CharaWork();

        public Group currentParty = null;
        public ContentGroup currentContentGroup = null;
        
        //public DateTime lastAiUpdate;

        public AIContainer aiContainer;
        public StatusEffectContainer statusEffects;

        // AI: faction, tags, owning content and owner (pets, trusts). See Meteor.Map.AI.
        public int factionId = Factions.Neutral;
        public readonly HashSet<string> tags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        public Encounter content;
        public Character ownerChara;
        public bool deferAttach;
        public HateContainer hateContainer;
        public Perception perception;
        public float spawnRotation;

        public Pet pet;

        private Dictionary<Modifier, double> modifiers = new Dictionary<Modifier, double>();

        protected ushort hpBase, hpMaxBase, mpBase, mpMaxBase, tpBase;
        protected BattleTemp baseStats = new BattleTemp();
        public ushort currentJob;
        public ushort newMainState;
        public float spawnX, spawnY, spawnZ;

        //I needed some values I could reuse for random stuff, delete later
        public int extraInt;
        public uint extraUint;
        public float extraFloat;

        protected Dictionary<string, UInt64> tempVars = new Dictionary<string, UInt64>();
        
        //Inventory        
        protected Dictionary<ushort, ItemPackage> itemPackages = new Dictionary<ushort, ItemPackage>();
        protected ReferencedItemPackage equipment;

        public Character(uint actorID)
            : base(actorID)
        {
            //Init timer array to "notimer"
            for (int i = 0; i < charaWork.statusShownTime.Length; i++)
                charaWork.statusShownTime[i] = 0;

            this.statusEffects = new StatusEffectContainer(this);

            // todo: move this somewhere more appropriate
            // todo: base this on equip and shit
            SetMod((uint)Modifier.AttackRange, 3);
            SetMod((uint)Modifier.Delay, (Program.Random.Next(30, 60) * 100));
            SetMod((uint)Modifier.MovementSpeed, (uint)moveSpeeds[2]);

            spawnX = positionX;
            spawnY = positionY;
            spawnZ = positionZ;
            perception = new Perception(this);
        }

        public Brain Brain => aiContainer?.GetController<Brain>();

        public Character TargetChara => target as Character;

        public bool HasTag(string tag) => tag != null && tags.Contains(tag);

        public bool IsHostileTo(Character other) => Factions.IsHostile(this, other);

        public bool IsFriendlyTo(Character other) => Factions.IsFriendly(this, other);

        public SubPacket CreateAppearancePacket()
        {
            SetActorAppearancePacket setappearance = new SetActorAppearancePacket(modelId, appearanceIds);
            return setappearance.BuildPacket(Id);
        }

        public SubPacket CreateInitStatusPacket()
        {
            return (SetActorStatusAllPacket.BuildPacket(Id, charaWork.status));
        }

        public SubPacket CreateSetActorIconPacket()
        {
            return SetActorIconPacket.BuildPacket(Id, currentActorIcon);
        }

        public SubPacket CreateSubStatePacket()
        {
            return SetActorSubStatePacket.BuildPacket(Id, currentSubState);
        }

        public void SetQuestGraphic(Player player, int graphicNum)
        {
            player.QueuePacket(SetActorQuestGraphicPacket.BuildPacket(Id, graphicNum));
        }

        public void SetCurrentContentGroup(ContentGroup group)
        {
            if (group != null)
                charaWork.currentContentGroup = group.GetTypeId();
            else
                charaWork.currentContentGroup = 0;

            currentContentGroup = group;

            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("charaWork/currentContentGroup", this);
            propPacketUtil.AddProperty("charaWork.currentContentGroup");
            CurrentArea.BroadcastPacketsAroundActor(this, propPacketUtil.Done());
        }

        //This logic isn't correct, order of GetStatusEffects() is not necessarily the same as the actual effects in game. Also sending every time at once isn't needed
        public List<SubPacket> GetActorStatusPackets()
        {
            var propPacketUtil = new ActorPropertyPacketUtil("charaWork/status", this);
            var i = 0;
            foreach (var effect in statusEffects.GetStatusEffects())
            {
                if (!effect.GetHidden())
                {
                    propPacketUtil.AddProperty(String.Format("charaWork.statusShownTime[{0}]", i));
                    propPacketUtil.AddProperty(String.Format("charaWork.statusShownTime[{0}]", i));
                    i++;
                }
            }
            return propPacketUtil.Done();
        }
        
        public void PlayAnimation(uint animId, bool onlySelf = false)
        {
            if (onlySelf)
            {
                if (this is Player)
                    ((Player)this).QueuePacket(PlayAnimationOnActorPacket.BuildPacket(Id, animId));
            }
            else
                CurrentArea.BroadcastPacketAroundActor(this, PlayAnimationOnActorPacket.BuildPacket(Id, animId));
        }
        
        // The client's KO sequence waits until the dying actor has no unfinished queued CommandResult, so
        // nothing may be sourced from an actor after its death 0x0134.
        private bool SuppressDeadSource()
        {
            if (!IsDead())
                return false;
            Program.Log.Debug("[battle] dropped CommandResult sourced from dead actor 0x{0:X}", Id);
            return true;
        }

        // The client queues a 0x0134 and applies it at the hit of a later CommandResult on the actor, so a
        // death sent after the killing blow is never applied: send it now instead of next tick.
        public void BroadcastStateNow()
        {
            if (CurrentArea == null)
                return;
            var packets = new List<SubPacket>();
            AddStatePackets(packets);
            CurrentArea.BroadcastPacketsAroundActor(this, packets);
        }

        // 0x0134 plus the mode-change pair (X00 0x72000062, X01 0x7C000062/21001) the client plays the
        // transition from. Players need both, or they neither collapse nor get up. Retail sends monsters
        // the X01 alone going active, and neither with a KO, whose stance motion snapped corpses upright.
        private void AddStatePackets(List<SubPacket> packets)
        {
            packets.Add(SetActorStatePacket.BuildPacket(Id, currentMainState, StateSubByte()));
            bool dying = currentMainState == SetActorStatePacket.MAIN_STATE_DEAD || currentMainState == SetActorStatePacket.MAIN_STATE_DEAD2;
            if (this is Player)
            {
                packets.Add(CommandResultX00Packet.BuildPacket(Id, 0x72000062, 0));
                packets.Add(CommandResultX01Packet.BuildPacket(Id, 0x7C000062, 21001, new CommandResult(Id, 0, 1)));
            }
            else if (!dying)
                packets.Add(CommandResultX01Packet.BuildPacket(Id, 0x7C000062, 21001, new CommandResult(Id, 0, 1)));
            updateFlags &= ~ActorUpdateFlags.State;
        }

        public void DoBattleAction(ushort commandId, uint animationId)
        {
            if (SuppressDeadSource())
                return;
            CurrentArea.BroadcastPacketAroundActor(this, CommandResultX00Packet.BuildPacket(Id, animationId, commandId));
        }

        public void DoBattleAction(ushort commandId, uint animationId, CommandResult result)
        {
            if (SuppressDeadSource())
                return;
            CurrentArea.BroadcastPacketAroundActor(this, CommandResultX01Packet.BuildPacket(Id, animationId, commandId, result));
            FlushDeathEnmityClears(new[] { result });
        }

        public void DoBattleAction(ushort commandId, uint animationId, CommandResult[] results)
        {
            if (SuppressDeadSource())
                return;
            int currentIndex = 0;

            while (true)
            {
                if (results.Length - currentIndex >= 10)
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX18Packet.BuildPacket(Id, animationId, commandId, results, ref currentIndex));
                else if (results.Length - currentIndex > 1)
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX10Packet.BuildPacket(Id, animationId, commandId, results, ref currentIndex));
                else if (results.Length - currentIndex == 1)
                {
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX01Packet.BuildPacket(Id, animationId, commandId, results[currentIndex]));
                    currentIndex++;
                }
                else
                    break;
            }
            FlushDeathEnmityClears(results);
        }

        public void DoBattleAction(ushort commandId, uint animationId, List<CommandResult> results)
        {
            if (SuppressDeadSource())
                return;
            int currentIndex = 0;

            while (true)
            {
                if (results.Count - currentIndex >= 10)
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX18Packet.BuildPacket(Id, animationId, commandId, results, ref currentIndex));
                else if (results.Count - currentIndex > 1)
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX10Packet.BuildPacket(Id, animationId, commandId, results, ref currentIndex));
                else if (results.Count - currentIndex == 1)
                {
                    CurrentArea.BroadcastPacketAroundActor(this, CommandResultX01Packet.BuildPacket(Id, animationId, commandId, results[currentIndex]));
                    currentIndex++;
                }
                else
                    break;

                //Sending multiple packets at once causes some issues. Setting any combination of these to zero changes what breaks
                //animationId = 0; //If more than one packet is sent out, only send the animation once to avoid double playing.
                //commandId = 0;
                //sourceActorId = 0;
            }
            FlushDeathEnmityClears(results);
        }

        private void FlushDeathEnmityClears(IEnumerable<CommandResult> results)
        {
            if (results == null || CurrentArea == null)
                return;
            HashSet<uint> seen = new HashSet<uint>();
            foreach (CommandResult result in results)
            {
                if (result == null || !seen.Add(result.targetId))
                    continue;
                if (CurrentArea.FindActorInArea<BattleNpc>(result.targetId) is BattleNpc mob)
                    mob.FlushPendingEnmityClear();
            }
        }

        #region ai stuff
        // stepSize and maxPath are unused; kept so old scripts still run. Stops polyRadius short.
        public void PathTo(float x, float y, float z, float stepSize = 0.70f, int maxPath = 40, float polyRadius = 0.0f)
        {
            aiContainer?.mover?.MoveTo(new Vector3(x, y, z), DefaultMoveState(), polyRadius);
        }

        // Call every tick to keep following. stepSize and maxPath are unused.
        public void FollowTarget(Actor target, float stepSize = 1.2f, int maxPath = 25, float radius = 0.0f)
        {
            if (target != null)
                aiContainer?.mover?.Chase(target.GetPosAsVector3(), Mover.MOVE_STATE_RUN, radius);
        }

        private ushort DefaultMoveState()
        {
            if (aiContainer != null && aiContainer.IsEngaged())
                return Mover.MOVE_STATE_ACTIVE;
            return isMovingToSpawn ? Mover.MOVE_STATE_RUN : Mover.MOVE_STATE_WALK;
        }

        public double GetMod(Modifier modifier)
        {
            return GetMod((uint)modifier);
        }

        public double GetMod(uint modifier)
        {
            double res;
            if (modifiers.TryGetValue((Modifier)modifier, out res))
                return res;
            return 0;
        }

        public void SetMod(uint modifier, double val)
        {
            if (modifiers.ContainsKey((Modifier)modifier))
                modifiers[(Modifier)modifier] = val;
            else
                modifiers.Add((Modifier)modifier, val);

            if (modifier >= 3 && modifier <= 35)
                updateFlags |= ActorUpdateFlags.Stats;
        }

        public void AddMod(Modifier modifier, double val)
        {
            AddMod((uint)modifier, val);
        }

        public void AddMod(uint modifier, double val)
        {

            double newVal = GetMod(modifier) + val;
            SetMod(modifier, newVal);
        }

        public void SubtractMod(Modifier modifier, double val)
        {
            SubtractMod((uint)modifier, val);
        }

        public void SubtractMod(uint modifier, double val)
        {
            double newVal = GetMod(modifier) - val;
            SetMod(modifier, newVal);
        }

        public void MultiplyMod(Modifier modifier, double val)
        {
            MultiplyMod((uint)modifier, val);
        }

        public void MultiplyMod(uint modifier, double val)
        {
            double newVal = GetMod(modifier) * val;
            SetMod(modifier, newVal);
        }

        public void DivideMod(Modifier modifier, double val)
        {
            DivideMod((uint)modifier, val);
        }

        public void DivideMod(uint modifier, double val)
        {
            double newVal = GetMod(modifier) / val;
            SetMod(modifier, newVal);
        }


        public virtual void OnPath(Vector3 point)
        {
            updateFlags |= ActorUpdateFlags.Position;
            this.isAtSpawn = false;
        }

        public override void Update(DateTime tick)
        {

        }

        public override void PostUpdate(DateTime tick, List<SubPacket> packets = null)
        {
            if (updateFlags != ActorUpdateFlags.None)
            {
                packets = packets ?? new List<SubPacket>();

                if ((updateFlags & ActorUpdateFlags.Appearance) != 0)
                {
                    packets.Add(new SetActorAppearancePacket(modelId, appearanceIds).BuildPacket(Id));
                }

                if ((updateFlags & ActorUpdateFlags.State) != 0)
                    AddStatePackets(packets);

                if ((updateFlags & ActorUpdateFlags.SubState) != 0)
                {
                    packets.Add(SetActorSubStatePacket.BuildPacket(Id, currentSubState));
                    //packets.Add(CommandResultX00Packet.BuildPacket(actorId, 0x72000062, 0));
                    //packets.Add(CommandResultX01Packet.BuildPacket(actorId, 0x7C000062, 21001, new CommandResult(actorId, 0, 1)));

                    updateFlags &= ~ActorUpdateFlags.SubState;
                    //DoBattleAction(21001, 0x7C000062, new BattleAction(this.actorId, 0, 1, 0, 0, 1)); //Attack Mode
                }

                if ((updateFlags & ActorUpdateFlags.Status) != 0)
                {

                    List<SubPacket> statusPackets = statusEffects.GetStatusPackets();
                    packets.AddRange(statusPackets);
                    statusPackets.Clear();
                    updateFlags &= ~ActorUpdateFlags.Status;
                }

                if ((updateFlags & ActorUpdateFlags.StatusTime) != 0)
                {
                    packets.AddRange(statusEffects.GetStatusTimerPackets());
                    statusEffects.ResetPropPacketUtil();
                    updateFlags &= ~ActorUpdateFlags.StatusTime;
                }

                if ((updateFlags & ActorUpdateFlags.HpTpMp) != 0)
                {
                    var propPacketUtil = new ActorPropertyPacketUtil("charaWork/stateAtQuicklyForAll", this);
                    propPacketUtil.AddProperty("charaWork.parameterSave.hp[0]");
                    propPacketUtil.AddProperty("charaWork.parameterSave.hpMax[0]");
                    propPacketUtil.AddProperty("charaWork.parameterSave.mp");
                    propPacketUtil.AddProperty("charaWork.parameterSave.mpMax");
                    propPacketUtil.AddProperty("charaWork.parameterTemp.tp");
                    packets.AddRange(propPacketUtil.Done());
                }

                base.PostUpdate(tick, packets);
            }
        }

        public virtual bool IsValidTarget(Character target, ValidTarget validTarget)
        {
            return !target.isStatic;
        }

        public virtual bool CanAttack()
        {
            return true;
        }

        public virtual bool CanUse(Character target, BattleCommand skill, CommandResult error = null)
        {
            return false;
        }


        public virtual uint GetAttackDelayMs()
        {
            return (uint)GetMod((uint)Modifier.Delay);
        }

        public virtual uint GetAttackRange()
        {
            return (uint)(GetMod((uint)Modifier.AttackRange) == 0 ? 3 : GetMod((uint)Modifier.AttackRange));
        }

        public virtual bool Engage(uint targid = 0, ushort newMainState = 0xFFFF)
        {
            // todo: attack the things
            /*if (newMainState != 0xFFFF)
            {
                currentMainState = newMainState;// this.newMainState = newMainState;
                updateFlags |= ActorUpdateFlags.State;
            }
            else*/ if (aiContainer.CanChangeState())
            {
                if (targid == 0)
                {
                    if (currentTarget != Actor.INVALID_ACTORID)
                        targid = currentTarget;
                    else if (currentLockedTarget != Actor.INVALID_ACTORID)
                        targid = currentLockedTarget;
                }
                //if (targid != 0)
                {
                    aiContainer.Engage(CurrentArea.FindActorInArea<Character>(targid));
                }
            }

            return false;
        }

        public virtual bool Engage(Character target)
        {
            aiContainer.Engage(target);
            return false;
        }

        public virtual bool Disengage(ushort newMainState = 0xFFFF)
        {
            /*if (newMainState != 0xFFFF)
            {
                currentMainState = newMainState;// this.newMainState = newMainState;
                updateFlags |= ActorUpdateFlags.State;
            }
            else*/ if (IsEngaged())
            {
                aiContainer.Disengage();
                return true;
            }
            return false;
        }
        
        public virtual void Cast(uint spellId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.Cast(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), spellId);
        }

        public virtual void Ability(uint abilityId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.Ability(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), abilityId);
        }

        public virtual void WeaponSkill(uint skillId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.WeaponSkill(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), skillId);
        }

        public virtual void Spawn(DateTime tick)
        {
            aiContainer.Reset();
            // todo: reset hp/mp/tp etc here
            ChangeState(SetActorStatePacket.MAIN_STATE_PASSIVE);
            SetHP((uint) GetMaxHP());
            SetMP((uint) GetMaxMP());
            RecalculateStats();
        }

        //AdditionalActions is the list of actions that EXP/Chain messages are added to
        public virtual void Die(DateTime tick, CommandResultContainer actionContainer = null)
        {
            // todo: actual despawn timer
            aiContainer.InternalDie(tick, 10);
            ChangeSpeed(0.0f, 0.0f, 0.0f, 0.0f);
        }

        public virtual void Despawn(DateTime tick)
        {
            
        }

        // Drops the death state, restores hpPercent of max HP and returns to passive. The state and
        // speeds go out now: left to the next tick, they arrived after the revive result and the client
        // dropped the player back into the KO pose.
        public virtual void Revive(int hpPercent = 100)
        {
            aiContainer.Reset();
            ChangeState(SetActorStatePacket.MAIN_STATE_PASSIVE);
            uint hp = (uint)Math.Max(1, (int)Math.Ceiling(GetMaxHP() * Math.Clamp(hpPercent, 1, 100) / 100.0));
            charaWork.parameterSave.hp[0] = (short)hp;
            updateFlags |= ActorUpdateFlags.HpTpMp;

            if (CurrentArea != null)
            {
                CurrentArea.BroadcastPacketsAroundActor(this, new List<SubPacket> { CreateStatePacket(), CreateSpeedPacket() });
                updateFlags &= ~(ActorUpdateFlags.State | ActorUpdateFlags.Speed);
            }
        }

        public bool IsDead()
        {
            return !IsAlive();
        }

        public bool IsAlive()
        {
            return !aiContainer.IsDead();// && GetHP() > 0;
        }

        public short GetHP()
        {
            // todo: 
            return charaWork.parameterSave.hp[0];
        }

        public short GetMaxHP()
        {
            return charaWork.parameterSave.hpMax[0];
        }

        public short GetMP()
        {
            return charaWork.parameterSave.mp;
        }

        public ushort GetTP()
        {
            return tpBase;
        }

        public short GetMaxMP()
        {
            return charaWork.parameterSave.mpMax;
        }

        public byte GetMPP()
        {
            return (byte)(charaWork.parameterSave.mpMax <= 0 ? 0 : (charaWork.parameterSave.mp / (float)charaWork.parameterSave.mpMax) * 100);
        }

        public byte GetTPP()
        {
            return (byte)((tpBase / 3000.0f) * 100);
        }

        public byte GetHPP()
        {
            return (byte)(charaWork.parameterSave.hp[0] == 0 ? 0 : (charaWork.parameterSave.hp[0] / (float) charaWork.parameterSave.hpMax[0]) * 100);
        }

        public void SetHP(uint hp)
        {
            charaWork.parameterSave.hp[0] = (short)hp;
            if (hp > charaWork.parameterSave.hpMax[0])
                SetMaxHP(hp);

            updateFlags |= ActorUpdateFlags.HpTpMp;
        }

        public void SetMaxHP(uint hp)
        {
            charaWork.parameterSave.hpMax[0] = (short)hp;
            updateFlags |= ActorUpdateFlags.HpTpMp;
        }

        public void SetMP(uint mp)
        {
            charaWork.parameterSave.mp = (short)mp;
            if (mp > charaWork.parameterSave.mpMax)
                SetMaxMP(mp);

            updateFlags |= ActorUpdateFlags.HpTpMp;
        }

        public void SetMaxMP(uint mp)
        {
            charaWork.parameterSave.mpMax = (short)mp;
            updateFlags |= ActorUpdateFlags.HpTpMp;
        }

        // todo: the following functions are virtuals since we want to check hidden item bonuses etc on player for certain conditions
        public virtual void AddHP(int hp, CommandResultContainer resultContainer = null)
        {
            // dont wanna die ded, don't want to send update if hp isn't actually changed
            if (IsAlive() && hp != 0)
            {
                int beforePct = GetHPP();
                var addHp = charaWork.parameterSave.hp[0] + hp;
                addHp = addHp.Clamp((short)GetMod((uint)Modifier.MinimumHpLock), charaWork.parameterSave.hpMax[0]);
                int change = addHp - charaWork.parameterSave.hp[0];
                charaWork.parameterSave.hp[0] = (short)addHp;

                updateFlags |= ActorUpdateFlags.HpTpMp;

                if (change > 0)
                    EventBus.Raise(new ActorEvent(ActorEventType.Healed, this, actingCharacter) { Amount = change });
                RaiseHpCrossed(beforePct, GetHPP());

                if (charaWork.parameterSave.hp[0] < 1)
                    Die(Program.Tick, resultContainer);
            }
        }

        // Who is acting while a battle command resolves, so heals and damage know their source.
        [ThreadStatic] public static Character actingCharacter;

        public readonly SortedSet<int> hpThresholds = new SortedSet<int>();

        private void RaiseHpCrossed(int before, int after)
        {
            if (before == after || hpThresholds.Count == 0)
                return;
            foreach (int t in hpThresholds)
            {
                if (before > t && after <= t)
                    EventBus.Raise(new ActorEvent(ActorEventType.HpCrossed, this) { Amount = t, Name = "down" });
                else if (before <= t && after > t)
                    EventBus.Raise(new ActorEvent(ActorEventType.HpCrossed, this) { Amount = t, Name = "up" });
            }
        }

        public void WatchHp(int percent)
        {
            hpThresholds.Add(percent);
        }

        public short GetClass()
        {
            return charaWork.parameterSave.state_mainSkill[0];
        }

        public short GetLevel()
        {
            return charaWork.parameterSave.state_mainSkillLevel;
        }

        public void AddMP(int mp)
        {
            if (IsAlive() && mp != 0)
            {
                charaWork.parameterSave.mp = (short)(charaWork.parameterSave.mp + mp).Clamp(ushort.MinValue, charaWork.parameterSave.mpMax);

                // todo: check hidden effects and shit

                updateFlags |= ActorUpdateFlags.HpTpMp;
            }
        }

        public void AddTP(int tp)
        {
            if (this is Ally)
                return;
            if (IsAlive() && tp != 0)
            {
                var addTp = charaWork.parameterTemp.tp + tp;
                
                addTp = addTp.Clamp((int) GetMod(Modifier.MinimumTpLock), 3000);
                charaWork.parameterTemp.tp = (short) addTp;
                tpBase = (ushort)charaWork.parameterTemp.tp;
                updateFlags |= ActorUpdateFlags.HpTpMp;

                if (tpBase >= 1000)
                    lua.LuaEngine.GetInstance().OnSignal("tpOver1000");
            }
        }

        public void DelHP(int hp, CommandResultContainer resultContainer = null)
        {
            AddHP((short)-hp, resultContainer);
        }

        public void DelMP(int mp)
        {
            AddMP(-mp);
        }

        public void DelTP(int tp)
        {
            AddTP(-tp);
        }

        virtual public void CalculateBaseStats()
        {
            // todo: apply mods and shit here, get race/level/job and shit
            uint hpMod = (uint) GetMod((uint)Modifier.Hp);
            if (hpMod != 0)
            {
                SetMaxHP(hpMod);
                uint hpp = (uint) GetMod((uint) Modifier.HpPercent);
                uint hp = hpMod;
                if(hpp != 0)
                {
                    hp = (uint) Math.Ceiling(((float)hpp / 100.0f) * hpMod);
                }
                SetHP(hp);
            }

            uint mpMod = (uint)GetMod((uint)Modifier.Mp);
            if (mpMod != 0)
            {
                SetMaxMP(mpMod);
                uint mpp = (uint)GetMod((uint)Modifier.MpPercent);
                uint mp = mpMod;
                if (mpp != 0)
                {
                    mp = (uint)Math.Ceiling(((float)mpp / 100.0f) * mpMod);
                }
                SetMP(mp);
            }
            // todo: recalculate stats and crap
            updateFlags |= ActorUpdateFlags.HpTpMp;

            // Keep a hit count already set by the database, a status or the weapon.
            if (GetMod((uint)Modifier.HitCount) <= 0)
                SetMod((uint)Modifier.HitCount, 1);
        }

        // Each layer remembers what it last added to each modifier, so recalculating a layer replaces
        // its share instead of stacking on top.
        private Dictionary<string, Dictionary<uint, double>> statLayers = new Dictionary<string, Dictionary<uint, double>>();

        public void SetStatLayer(string layer, uint modifier, double value)
        {
            Dictionary<uint, double> mods;
            if (!statLayers.TryGetValue(layer, out mods))
                statLayers[layer] = mods = new Dictionary<uint, double>();

            double previous;
            mods.TryGetValue(modifier, out previous);
            if (value != previous)
                AddMod(modifier, value - previous);
            mods[modifier] = value;
        }

        // Modifiers missing from values go back to 0.
        public void ReplaceStatLayer(string layer, Dictionary<uint, double> values)
        {
            Dictionary<uint, double> mods;
            if (statLayers.TryGetValue(layer, out mods))
            {
                foreach (var modifier in new List<uint>(mods.Keys))
                    if (!values.ContainsKey(modifier))
                        SetStatLayer(layer, modifier, 0);
            }
            foreach (var kv in values)
                SetStatLayer(layer, kv.Key, kv.Value);
        }

        public double GetStatLayer(string layer, uint modifier)
        {
            Dictionary<uint, double> mods;
            double value;
            if (statLayers.TryGetValue(layer, out mods) && mods.TryGetValue(modifier, out value))
                return value;
            return 0;
        }

        public void SetBaseStat(uint modifier, double value)
        {
            SetStatLayer("base", modifier, value);
        }

        public double GetBaseStat(uint modifier)
        {
            return GetStatLayer("base", modifier);
        }

        public const string LAYER_WELL_FED = "status:wellfed";
        public const string LAYER_MEDICATED = "status:medicated";

        // Food and medicine buffs: min(stat x %, cap) per modifier, sized from the stat without this
        // layer (and, for food, without medicine). Lua: Well Fed and Medicated pass the item id.
        public bool ApplyConsumableBuff(string layer, double itemId)
        {
            ConsumableData data = ConsumableData.Get((uint)itemId);
            if (data == null)
            {
                ClearConsumableBuff(layer);
                return false;
            }

            var values = new Dictionary<uint, double>();
            foreach (ConsumableData.Effect effect in data.effects)
            {
                double stat = GetMod(effect.modifier) - GetStatLayer(layer, effect.modifier);
                if (layer == LAYER_WELL_FED)
                    stat -= GetStatLayer(LAYER_MEDICATED, effect.modifier);
                if (effect.modifier == (uint)Modifier.Hp || effect.modifier == (uint)Modifier.Mp)
                {
                    double baseValue = GetBaseStat(effect.modifier);
                    if (baseValue > 0)
                        stat = baseValue;
                }
                values.TryGetValue(effect.modifier, out double previous);
                values[effect.modifier] = previous + effect.Compute(stat);
            }
            ReplaceStatLayer(layer, values);
            SyncPoolsFromMods();
            return true;
        }

        public void ClearConsumableBuff(string layer)
        {
            ReplaceStatLayer(layer, new Dictionary<uint, double>());
            SyncPoolsFromMods();
        }

        // Max HP/MP follow Modifier.Hp/Mp after a layer moved them, for characters with a base layer.
        private void SyncPoolsFromMods()
        {
            if (GetBaseStat((uint)Modifier.Hp) > 0)
            {
                SetMaxHP((uint)Math.Max(1, Math.Floor(GetMod(Modifier.Hp))));
                if (GetHP() > GetMaxHP())
                    SetHP((uint)GetMaxHP());
            }
            if (GetBaseStat((uint)Modifier.Mp) > 0)
            {
                SetMaxMP((uint)Math.Max(0, Math.Floor(GetMod(Modifier.Mp))));
                if (GetMP() > GetMaxMP())
                    SetMP((uint)GetMaxMP());
            }
        }

        public void RecalculateStats()
        {
            //CalculateBaseStats();
        }

        public void SetStat(uint statId, int val)
        {
            charaWork.battleTemp.generalParameter[statId] = (short)val;
        }

        public short GetStat(uint statId)
        {
            return charaWork.battleTemp.generalParameter[statId];
        }

        public virtual float GetSpeed()
        {
            // todo: for battlenpc/player calculate speed
            return (float) GetMod((uint)Modifier.MovementSpeed);
        }

        public const uint ANIM_MESSAGE_ONLY = 0x7F000062;
        public const uint ANIM_CAST_STOP = 0x7F000002;
        public const ushort TEXT_IS_PARALYZED = 30918;
        public const int PARALYSIS_FAIL_PERCENT = 25;

        // Auto-attack hits from the weapon alone; Spinning Heel adds one on top.
        public int autoAttackBaseHits => this is Player player ? Math.Max(1, player.GetWeaponBaseHits()) : 1;

        // A command that fails as it resolves: the caster's own X01 with the failure text. Monsters
        // stop a cast with a different timeline than players.
        public CommandResult BuildCommandFailResult(ushort textId, bool stopCast)
        {
            var result = new CommandResult(Id, textId, 0);
            result.animation = !stopCast ? ANIM_MESSAGE_ONLY : (this is Player ? ANIM_CAST_STOP : 0x7F000063);
            return result;
        }

        // A paralyzed actor's swing, weaponskill, ability or spell fails a quarter of the time and
        // costs nothing.
        public bool RollParalysis()
        {
            return statusEffects.HasStatusEffect(StatusEffectId.Paralysis) && Program.Random.Next(100) < PARALYSIS_FAIL_PERCENT;
        }

        public void SendParalyzedResult(ushort commandId, bool stopCast)
        {
            CommandResult result = BuildCommandFailResult(TEXT_IS_PARALYZED, stopCast);
            DoBattleAction(commandId, result.animation, result);
        }

        public virtual void OnAttack(State state, CommandResult action, ref CommandResult error)
        {
            var target = state.GetTarget();
            // todo: change animation based on equipped weapon
            // todo: get hitrate and shit, handle protect effect and whatever
            if (BattleUtils.TryAttack(this, target, action, ref error))
            {
                //var packet = BattleActionX01Packet.BuildPacket(owner.actorId, owner.actorId, target.actorId, (uint)0x19001000, (uint)0x8000604, (ushort)0x765D, (ushort)BattleActionX01PacketCommand.Attack, (ushort)damage, (byte)0x1);
            }

            // todo: call onAttack/onDamageTaken
            //BattleUtils.DamageTarget(this, target, DamageTakenType.Attack, action);
        }

        public virtual void OnCast(State state, CommandResult[] actions, BattleCommand spell, ref CommandResult[] errors)
        {
            // damage is handled in script
            var spellCost = spell.CalculateMpCost(this);
            this.DelMP(spellCost); // mpCost can be set in script e.g. if caster has something for free spells

            foreach (CommandResult action in actions)
            {
                if (CurrentArea.FindActorInArea<Character>(action.targetId) is Character)
                {
                    //BattleUtils.HandleHitType(this, chara, action);
                    //BattleUtils.DoAction(this, chara, action, DamageTakenType.Magic);
                }
            }
            lua.LuaEngine.GetInstance().OnSignal("spellUsed");
        }

        public virtual void OnWeaponSkill(State state, CommandResult[] actions, BattleCommand skill, ref CommandResult[] errors)
        {
            // damage is handled in script

            foreach (CommandResult action in actions)
            {
                //Should we just store the character insteado f having to find it again?
                if (CurrentArea.FindActorInArea<Character>(action.targetId) is Character)
                {
                    //BattleUtils.DoAction(this, chara, action, DamageTakenType.Weaponskill);
                }
            }

            this.DelTP(skill.tpCost);
        }

        public virtual void OnAbility(State state, CommandResult[] actions, BattleCommand ability, ref CommandResult[] errors)
        {
            foreach (var action in actions)
            {
                if (CurrentArea.FindActorInArea<Character>(action.targetId) is Character)
                {
                    //BattleUtils.DoAction(this, chara, action, DamageTakenType.Ability);
                }
            }
        }

        public virtual void OnSpawn()
        {

        }

        public virtual void OnDeath()
        {

        }

        public virtual void OnDespawn()
        {

        }

        public virtual void OnDamageDealt(Character defender, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            switch (action.hitType)
            {
                case (HitType.Miss):
                    OnMiss(defender, skill, action, actionContainer);
                    break;
                case (HitType.Crit):
                    OnCrit(defender, skill, action, actionContainer);
                    OnHit(defender, skill, action, actionContainer);
                    break;
                default:
                    OnHit(defender, skill, action, actionContainer);
                    break;
            }

            // Only landed auto-attacks give TP; weaponskills, spells and abilities give none.
            if (action.commandType == CommandType.AutoAttack && action.hitType != HitType.Miss)
            {
                if (IsMonster())
                    AddTP(300);
                else
                {
                    // round(100 x delay x (1 + Store TP / 1000)) per swing, split across the weapon's own
                    // hits (fists hit twice). Extra hits beyond those add half a swing each. A trait's Store
                    // TP multiplies with gear's instead of adding to it.
                    double weaponDelay = GetMod(Modifier.Delay) / 1000.0;
                    double traitStoreTp = GetStatLayer("trait", (uint)Modifier.StoreTp);
                    var storeTPPercent = (1 + (GetMod(Modifier.StoreTp) - traitStoreTp) * 0.001) * (1 + traitStoreTp * 0.001);
                    int roundTP = (int)Math.Round(weaponDelay * 100 * storeTPPercent, MidpointRounding.AwayFromZero);
                    int baseHits = autoAttackBaseHits;
                    int hitNum = Math.Max(1, (int)action.hitNum);
                    if (hitNum <= baseHits)
                        AddTP(roundTP * hitNum / baseHits - roundTP * (hitNum - 1) / baseHits);
                    else
                        AddTP((int)Math.Round(roundTP * 0.5, MidpointRounding.AwayFromZero));
                }
            }
        }

        public virtual void OnDamageTaken(Character attacker, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            if (attacker != this)
                lastAttackedTime = DateTime.Now;
            switch (action.hitType)
            {
                case (HitType.Miss):
                    OnEvade(attacker, skill, action, actionContainer);
                    break;
                case (HitType.Parry):
                    OnParry(attacker, skill, action, actionContainer);
                    break;
                case (HitType.Block):
                    OnBlock(attacker, skill, action, actionContainer);
                    break;
            }

            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnDamageTaken, "onDamageTaken", attacker, this, skill, action, actionContainer);
            if (action.hitType != HitType.Miss && action.hitType != HitType.Evade)
                EventBus.Raise(new ActorEvent(ActorEventType.Damaged, this, attacker) { Amount = action.amount, ActionId = skill?.id ?? 0 });

            // TP from damage taken: ceil(damage x k). Players: k falls with level, 4.414 e^(-0.0645 level),
            // the middle of the curves that reproduce every captured hit. Monsters: k is about 1600 / max HP.
            double tpModifier = IsMonster()
                ? 1600.0 / Math.Max(1, (int)GetMaxHP())
                : 4.414 * Math.Exp(-0.0645 * GetLevel());
            AddTP((int)Math.Ceiling(tpModifier * action.amount));
        }

        public UInt64 GetTempVar(string name)
        {
            UInt64 retVal = 0;
            if (tempVars.TryGetValue(name, out retVal))
                return retVal;
            return 0;
        }

        // cause lua is a dick
        public void SetTempVar(string name, uint val)
        {
            if (tempVars.ContainsKey(name))
                tempVars[name] = val;
        }

        public void SetTempVar(string name, UInt64 val)
        {
            if (tempVars.ContainsKey(name))
                tempVars[name] = val;
        }

        public void ResetTempVars()
        {
            tempVars.Clear();
        }

        #region lua helpers
        public bool IsEngaged()
        {
            return aiContainer.IsEngaged();
        }

        // Natural regen, per 3 s tick, as a share of max HP/MP by consecutive ticks standing still.
        // Out of combat: 1.5% while moving or on the first still tick, then 2.5%, 4.5%, 7.5%. In
        // combat: nothing while moving, then 1%, 3%, 6%. A tick in which we acted or were hit gives 0.
        public static readonly double[] NATURAL_REGEN_OOC = { 0.015, 0.025, 0.045, 0.075 };
        public static readonly double[] NATURAL_REGEN_COMBAT = { 0.01, 0.03, 0.06 };
        public const float NATURAL_REGEN_MOVE_EPSILON = 0.1f;

        public DateTime lastActionTime = DateTime.MinValue;
        public DateTime lastAttackedTime = DateTime.MinValue;
        private int stationaryRegenTicks;
        private float regenLastX, regenLastY, regenLastZ;
        private DateTime lastRegenTickTime = DateTime.MinValue;

        public static double NaturalRegenPercent(int stillTicks, bool inCombat)
        {
            if (inCombat)
                return stillTicks <= 0 ? 0 : NATURAL_REGEN_COMBAT[Math.Min(stillTicks, NATURAL_REGEN_COMBAT.Length) - 1];
            return NATURAL_REGEN_OOC[Math.Min(Math.Max(stillTicks, 1), NATURAL_REGEN_OOC.Length) - 1];
        }

        // Called on the status container's 3 s tick. HP/MP only in passive mode with no DoT on; TP
        // decays by 90 out of combat.
        public void NaturalRegenTick()
        {
            DateTime now = DateTime.Now;
            float dx = positionX - regenLastX, dy = positionY - regenLastY, dz = positionZ - regenLastZ;
            bool moved = dx * dx + dy * dy + dz * dz > NATURAL_REGEN_MOVE_EPSILON * NATURAL_REGEN_MOVE_EPSILON;
            regenLastX = positionX; regenLastY = positionY; regenLastZ = positionZ;
            bool busy = lastActionTime > lastRegenTickTime || lastAttackedTime > lastRegenTickTime;
            lastRegenTickTime = now;
            stationaryRegenTicks = (moved || busy) ? 0 : Math.Min(stationaryRegenTicks + 1, 1000);

            if (!IsAlive())
                return;

            bool inCombat = CurrentArea != null && IsInCombat();
            if (!busy && currentMainState == SetActorStatePacket.MAIN_STATE_PASSIVE && GetMod(Modifier.RegenDown) <= 0)
            {
                double pct = NaturalRegenPercent(stationaryRegenTicks, inCombat);
                if (pct > 0 && GetHP() < GetMaxHP())
                    AddHP((int)Math.Floor(GetMaxHP() * pct) + (int)GetMod(Modifier.RestingHp));
                if (pct > 0 && GetMP() < GetMaxMP())
                    AddMP((int)Math.Floor(GetMaxMP() * pct) + (int)GetMod(Modifier.RestingMp));
            }

            if (!inCombat && GetTP() > 0)
                AddTP(-90);
        }

        // Engaged with a living enemy, or on the hate list of a living mob nearby.
        public bool IsInCombat()
        {
            if (IsEngaged() && target is Character t && t.IsAlive() && IsHostileTo(t))
                return true;
            foreach (var mob in CurrentArea.GetActorsAroundActor<BattleNpc>(this, 50))
            {
                if (mob.IsAlive() && mob.hateContainer != null && mob.hateContainer.HasHateForTarget(this))
                    return true;
            }
            return false;
        }

        public bool IsPlayer()
        {
            return this is Player;
        }

        public bool IsMonster()
        {
            return this is BattleNpc;
        }

        public bool IsPet()
        {
            return this is Pet;
        }

        public bool IsAlly()
        {
            return this is Ally;
        }

        public bool IsDiscipleOfWar()
        {
            return GetClass() < CLASSID_THM;
        }

        public bool IsDiscipleOfMagic()
        {
            return GetClass() >= CLASSID_THM && currentJob < CLASSID_CRP;
        }

        public bool IsDiscipleOfHand()
        {
            return GetClass() >= CLASSID_CRP && currentJob < CLASSID_MIN;
        }

        public bool IsDiscipleOfLand()
        {
            return GetClass() >= CLASSID_MIN;
        }
        #endregion lua helpers
        #endregion ai stuff

        //Reset procs. Only send packet if any procs were actually reset. 
        //This assumes you can't use weaponskills between getting a proc and using the procced ability
        public void ResetProcs()
        {
            var propPacketUtil = new ActorPropertyPacketUtil("charaWork/timingCommand", this);
            bool shouldSend = false;
            for (int i = 0; i < 4; i++)
            {
                if (charaWork.battleTemp.timingCommandFlag[i])
                {
                    shouldSend = true;
                    charaWork.battleTemp.timingCommandFlag[i] = false;
                    propPacketUtil.AddProperty(String.Format("charaWork.battleTemp.timingCommandFlag[{0}]", i));
                }
            }

            if (shouldSend && this is Player)
                ((Player)this).QueuePackets(propPacketUtil.Done());
        }

        //Set given proc to true and send packet if this is a player
        // todo: hidden status effects for timing when the procs fall off
        public void SetProc(int procId, bool val = true)
        {
            charaWork.battleTemp.timingCommandFlag[procId] = val;
            uint effectId = (uint)StatusEffectId.EvadeProc + (uint)procId;

            //If a proc just occurred, add a hidden effect effect
            if (val)
            {
                StatusEffect procEffect = Server.GetWorldManager().GetStatusEffect(effectId);
                procEffect.SetDuration(5);
                statusEffects.AddStatusEffect(procEffect, this);
            }
            //Otherwise we're reseting a proc, remove the status
            else
            {
                statusEffects.RemoveStatusEffect(statusEffects.GetStatusEffectById((uint)effectId));
            }

            if (this is Player)
            {
                var propPacketUtil = new ActorPropertyPacketUtil("charaWork/timingCommand", this);
                propPacketUtil.AddProperty(String.Format("charaWork.battleTemp.timingCommandFlag[{0}]", procId));
                ((Player)this).QueuePackets(propPacketUtil.Done());
            }
        }

        public HitDirection GetHitDirection(Actor target)
        {
            //Get between taget's position and our position
            double angle = Vector3.GetAngle(target.GetPosAsVector3(), GetPosAsVector3());
            //Add to the target's rotation, mod by 2pi. This is the angle relative to where the target is looking
            //Actor's rotation is 0 degrees on their left side, rotate it by 45 degrees so that quadrants line up with sides
            angle = (angle + target.rotation - (.25 * Math.PI)) % (2 * Math.PI);
            //Make positive
            if (angle < 0)
                angle = angle + (2 * Math.PI);

            //Get the side we're on. 0 is front, 1 is right, 2 is rear, 3 is left
            var side = (int) (angle / (.5 * Math.PI)) % 4;

            return (HitDirection) (1 << side);
        }

        //Called when this character evades attacker's action
        public void OnEvade(Character attacker, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            SetProc((ushort)HitType.Evade);
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnEvade, "onEvade", attacker, this, skill, action, actionContainer);
        }

        //Called when this character blocks attacker's action
        public void OnBlock(Character attacker, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            SetProc((ushort)HitType.Block);
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnBlock, "onBlock", attacker, this, skill, action, actionContainer);
        }

        //Called when this character parries attacker's action
        public void OnParry(Character attacker, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            SetProc((ushort)HitType.Parry);
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnParry, "onParry", attacker, this, skill, action, actionContainer);
        }

        //Called when this character misses
        public void OnMiss(Character defender, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            SetProc((ushort)HitType.Miss);
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnMiss, "onMiss", this, defender, skill, action, actionContainer);
        }

        public void OnHit(Character defender, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnHit, "onHit", this, defender, skill, action, actionContainer);
        }

        public void OnCrit(Character defender, BattleCommand skill, CommandResult action, CommandResultContainer actionContainer = null)
        {
            statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnCrit, "onCrit", this, defender, skill, action, actionContainer);
        }

        //The order of messages that appears after using a command is:

        //1. Cast start messages. (ie "You begin casting... ")
        //2. Messages from buffs that activate before the command actually starts, like Power Surge or Presence of Mind. (This may be wrong and these could be the same as 4.)
        //3. If the command is a multi-hit command, this is where the "You use [command] on [target]" message goes

        //Then, for each hit:
        //4. Buffs that activate before a command hits, like Blindside
        //5. The hit itself. For single hit commands this message is "Your [command] hits [target] for x damage" for multi hits it's "[Target] takes x points of damage"
        //6. Stoneskin falling off
        //6. Buffs that activate after a command hits, like Aegis Boon and Divine Veil

        //After all hits
        //7. If it's a multi-hit command there's a "{numhits]fold attack..." message or if all hits miss an "All attacks missed" message
        //8. Buffs that fall off after the skill ends, like Excruciate

        //For every target defeated:
        //8. Defeat message
        //9. EXP message
        //10. EXP chain message


        //folder is probably temporary until move to cached scripts is complete
        public void DoBattleCommand(BattleCommand command, string folder)
        {
            //List<BattleAction> actions = new List<BattleAction>();
            CommandResultContainer actions = new CommandResultContainer();
            var previousActor = actingCharacter;
            actingCharacter = this;
            try
            {
                DoBattleCommandFor(command, folder, actions);
            }
            finally
            {
                actingCharacter = previousActor;
            }
            EventBus.Raise(new ActorEvent(ActorEventType.ActionDone, this, command.targetFind.GetMainTarget()) { ActionId = command.id });
        }

        private void DoBattleCommandFor(BattleCommand command, string folder, CommandResultContainer actions)
        {
            lastActionTime = DateTime.Now;
            var targets = command.targetFind.GetTargets();
            bool hitTarget = false;
            bool comboLanded = false;

            if (targets.Count > 0)
            {
                statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnCommandStart, "onCommandStart", this, command, actions);

                foreach (var chara in targets)
                {
                    ushort hitCount = 0;
                    ushort totalDamage = 0;
                    for (int hitNum = 1; hitNum <= command.numHits; hitNum++)
                    {
                        var action = new CommandResult(chara.Id, command, (byte)GetHitDirection(chara), (byte) hitNum);
                        
                        //uncached script
                        lua.LuaEngine.CallLuaBattleCommandFunction(this, command, folder, "onSkillFinish", this, chara, command, action, actions);
                        //cached script
                        //skill.CallLuaFunction(owner, "onSkillFinish", this, chara, command, action, actions);
                        if (action.ContinuesCombo())
                            comboLanded = true;
                        if (action.ActionLanded())
                        {
                            hitTarget = true;
                            hitCount++;
                            totalDamage += action.amount;
                        }
                    }

                    if (command.numHits > 1)
                    {
                        //30442: [hitCount]fold Attack! [chara] takes a total of totalDamage points of damage.
                        //30450: All attacks miss!
                        ushort textId = (ushort) (hitTarget ? 30442 : 30450);
                        actions.AddAction(new CommandResult(chara.Id, textId, 0, totalDamage, (byte)hitCount));
                    }
                }

                statusEffects.CallLuaFunctionByFlag((uint)StatusEffectFlags.ActivateOnCommandFinish, "onCommandFinish", this, command, actions);
            }
            else
            {
                actions.AddAction(new CommandResult(Id, 30202, 0));
            }

            DelMP(command.CalculateMpCost(this));
            DelTP(command.CalculateTpCost(this));

            // The client shows and the server enforces a recast through the command's hotbar slot.
            if (this is Player player && command.recastTimeMs > 0)
            {
                ushort slot = player.FindFirstCommandSlotById(command.id);
                int index = slot - player.charaWork.commandBorder;
                if (index >= 0 && index < 30)
                {
                    player.charaWork.parameterSave.commandSlot_recastTime[index] = Utils.UnixTimeStampUTC(DateTime.Now.AddMilliseconds(command.recastTimeMs));
                    player.charaWork.parameterTemp.maxCommandRecastTime[index] = (ushort)command.maxRecastTimeSeconds;
                    player.UpdateRecastTimers(new List<ushort> { slot });
                }
            }

            //Now that we know if we hit the target we can check if the combo continues
            if (this is Player)
            {
                if (command.isCombo && comboLanded)
                    ((Player)this).SetCombos(command.comboNextCommandId);
                //Only reset combo if the command is a spell or weaponskill, since abilities can be used between combo skills
                else if (command.commandType == CommandType.Spell || command.commandType == CommandType.WeaponSkill)
                    ((Player)this).SetCombos();
            }


            actions.CombineLists();
            DoBattleAction(command.id, command.battleAnimation, actions.GetList());
        }

        public List<Character> GetPartyMembersInRange(uint range)
        {
            TargetFind targetFind = new TargetFind(this);
            targetFind.SetAOEType(ValidTarget.Party, TargetFindAOEType.Circle, TargetFindAOETarget.Self, range, 0, 10, 0, 0);
            targetFind.FindWithinArea(this, ValidTarget.Party, TargetFindAOETarget.Self);
            return targetFind.GetTargets();
        }

        #region Inventory
        public void SendItemPackage(Player player, uint id)
        {
            if (!itemPackages.ContainsKey((ushort)id))
                return;

            player.QueuePacket(InventoryBeginChangePacket.BuildPacket(Id, true));
            itemPackages[(ushort)id].SendFullPackage(player);
            player.QueuePacket(InventoryEndChangePacket.BuildPacket(Id));
        }

        public void AddItem(uint catalogID)
        {
            AddItem(catalogID, 1);
        }

        public void AddItem(uint catalogID, int quantity)
        {
            AddItem(catalogID, quantity, 1);
        }

        public void AddItem(uint catalogID, int quantity, byte quality)
        {
            ushort itemPackage = GetPackageForItem(catalogID);
            if (itemPackages.ContainsKey(itemPackage))
            {
                itemPackages[itemPackage].AddItem(catalogID, quantity, quality);
            }
        }

        public void AddItem(InventoryItem item)
        {
            ushort itemPackage = GetPackageForItem(item.GetItemData().catalogID);
            if (itemPackages.ContainsKey(itemPackage))
            {
                itemPackages[itemPackage].AddItem(item);
            }
        }

        public void MoveItem(InventoryItem item, ushort destinationPackage)
        {
            ushort sourcePackage = item.itemPackage;

            if (!itemPackages.ContainsKey(sourcePackage) && !itemPackages.ContainsKey(destinationPackage))
                return;
            
            itemPackages[sourcePackage].MoveItem(item, itemPackages[destinationPackage]);
        }

        public void RemoveItem(uint catalogID)
        {
            RemoveItem(catalogID, 1);
        }

        public void RemoveItem(uint catalogID, int quantity)
        {
            RemoveItem(catalogID, quantity, 1);
        }

        public void RemoveItem(uint catalogID, int quantity, byte quality)
        {
            ushort itemPackage = GetPackageForItem(catalogID);
            if (itemPackages.ContainsKey(itemPackage))
            {
                itemPackages[itemPackage].RemoveItem(catalogID, quantity, quality);
            }
        }

        public void RemoveItemAtSlot(ushort itemPackage, ushort slot)
        {
            if (itemPackages.ContainsKey(itemPackage))
            {
                itemPackages[itemPackage].RemoveItemAtSlot(slot);
            }
        }

        public void RemoveItem(InventoryItem item)
        {
            itemPackages[item.itemPackage].RemoveItem(item);
        }

        public bool HasItem(uint catalogID)
        {
            return HasItem(catalogID, 1);
        }

        public bool HasItem(uint catalogID, int minQuantity)
        {
            return HasItem(catalogID, minQuantity, 1);
        }

        public bool HasItem(uint catalogID, int minQuantity, byte quality)
        {
            ushort itemPackage = GetPackageForItem(catalogID);
            if (itemPackages.ContainsKey(itemPackage))
            {
                return itemPackages[itemPackage].HasItem(catalogID, minQuantity, quality);
            }
            return false;
        }

        public bool HasItem(InventoryItem item)
        {
            ushort itemPackage = GetPackageForItem(item.GetItemData().catalogID);
            if (itemPackages.ContainsKey(itemPackage))
            {
                //return itemPackages[itemPackage].HasItem(item);
                return false; //TODO FIX
            }
            else
                return false;
        }

        public InventoryItem GetItem(LuaUtils.ItemRefParam reference)
        {
            if (reference.actorId != Id)
                return null;
            if (itemPackages.ContainsKey(reference.itemPackage))
            {
                return itemPackages[reference.itemPackage].GetItemAtSlot(reference.slot);
            }
            return null;
        }

        public ItemPackage GetItemPackage(ushort package)
        {
            if (itemPackages.ContainsKey(package))
                return itemPackages[package];
            else
                return null;
        }

        public ushort GetPackageForItem(uint catalogID)
        {
            ItemData data = Server.GetItemGamedata(catalogID);

            if (data == null)
                return ItemPackage.NORMAL;
            else
            {
                if (data.IsMoney())
                    return ItemPackage.CURRENCY_CRYSTALS;
                else if (data.IsImportant())
                    return ItemPackage.KEYITEMS;
                else
                    return ItemPackage.NORMAL;
            }
        }

        //public void removeItem(byUniqueId)
        //public void removeItem(byUniqueId, quantity)
        //public void removeItem(slot)
        //public void removeItem(slot, quantity)

        #endregion

    }
}
