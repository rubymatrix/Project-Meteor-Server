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
using Meteor.Map.AI;
using Meteor.Common;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.controllers;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.utils;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.actors.group;
using Meteor.Map.Actors.Chara;
using Meteor.Map.actors.director;

namespace Meteor.Map.Actors
{
    [Flags]
    enum DetectionType
    {
        None                  = 0x00,
        Sight                 = 0x01,
        Scent                 = 0x02,
        Sound                 = 0x04,
        LowHp                 = 0x08,
        IgnoreLevelDifference = 0x10,
        Magic                 = 0x20,
    }

    enum KindredType
    {
        Unknown   = 0,
        Beast     = 1,
        Plantoid  = 2,
        Aquan     = 3,
        Spoken    = 4,
        Reptilian = 5,
        Insect    = 6,
        Avian     = 7,
        Undead    = 8,
        Cursed    = 9,
        Voidsent  = 10,
    }

    class BattleNpc : Npc
    {
        public DetectionType detectionType;
        public KindredType kindredType;
        public bool neutral;
        public byte linkType;
        protected uint despawnTime;
        protected uint respawnTime;
        protected uint spawnDistance;
        protected uint bnpcId;
        public Character lastAttacker;

        public uint dropListId;

        public uint poolId, genusId;
        public ModifierList poolMods;
        public ModifierList genusMods;
        public ModifierList spawnMods;

        protected Dictionary<MobModifier, Int64> mobModifiers = new Dictionary<MobModifier, Int64>();

        private MonsterParty monsterParty;
        private bool attached;

        // Which kind profile (ai/kinds/<kind>.lua) the brain starts from.
        public virtual string Kind => "BattleNpc";

        public BattleNpc(int actorNumber, ActorClass actorClass, string uniqueId, Area spawnedArea, float posX, float posY, float posZ, float rot,
            ushort actorState, uint animationId, string customDisplayName)
            : base(actorNumber, actorClass, uniqueId, spawnedArea, posX, posY, posZ, rot, actorState, animationId, customDisplayName)  
        {
            this.aiContainer = new AIContainer(this, new Brain(this, Kind), new Mover(this), new TargetFind(this));

            //this.currentSubState = SetActorStatePacket.SUB_STATE_MONSTER;
            //this.currentMainState = SetActorStatePacket.MAIN_STATE_ACTIVE;

            //charaWork.property[2] = 1;
            //npcWork.hateType = 1;
            
            this.hateContainer = new HateContainer(this);
            this.factionId = Factions.Monster;

            spawnX = posX;
            spawnY = posY;
            spawnZ = posZ;
            spawnRotation = rot;

            despawnTime = 10;
            CalculateBaseStats();
        }

        public override void CalculateBaseStats()
        {
            lua.LuaEngine.CallLuaScriptFileFunction(ConfigConstants.OPTIONS_SCRIPTPATH + lua.LuaEngine.FILEPATH_BATTLENPC_STATS, "onCalculateBaseStats", this);
            base.CalculateBaseStats();
        }

        public override List<SubPacket> GetSpawnPackets(Player player, ushort spawnType)
        {
            List<SubPacket> subpackets = new List<SubPacket>();
            if (IsAlive())
            {
                subpackets.Add(CreateAddActorPacket());
                subpackets.AddRange(GetEventConditionPackets());
                subpackets.Add(CreateSpeedPacket());
                subpackets.Add(CreateSpawnPositonPacket(0x0));

                subpackets.Add(CreateAppearancePacket());

                subpackets.Add(CreateNamePacket());
                if (player != null && HasMonsterParty() && CurrentArea != null)
                    subpackets.AddRange(GetMonsterParty().BuildSpawnPackets(player.Id, CurrentArea.ZoneId));
                subpackets.Add(CreateStatePacket());
                subpackets.Add(CreateSubStatePacket());
                subpackets.Add(CreateInitStatusPacket());
                subpackets.Add(CreateSetActorIconPacket());
                subpackets.Add(CreateIsZoneingPacket());
                subpackets.Add(CreateScriptBindPacket(player));
                subpackets.Add(GetHateTypePacket(player));
                if (player != null)
                    subpackets.Add(GetEnmityIndicatorPacket(player));
            }
            return subpackets;
        }

        public SubPacket GetHateTypePacket(Player player)
        {
            var propPacketUtil = new ActorPropertyPacketUtil("npcWork/hate", this);
            propPacketUtil.AddProperty("npcWork.hateType");
            return propPacketUtil.Done()[0];
        }

        #region Claim (nameplate colour)

        public bool HasMonsterParty()
        {
            return !(this is Ally) && !(this is Pet);
        }

        public MonsterParty GetMonsterParty()
        {
            if (monsterParty == null && HasMonsterParty())
                monsterParty = MonsterParty.Create(Id);
            return monsterParty;
        }

        public ulong GetClaimPartyGroupId()
        {
            return monsterParty != null ? monsterParty.occupancyGroupId : 0;
        }

        public static ulong GetClaimPartyGroupId(Character chara)
        {
            Character owner = GetCreditOwner(chara);
            if (owner is Player && owner.currentParty is Party party)
                return party.groupIndex;
            return 0;
        }

        public static Character GetCreditOwner(Character chara)
        {
            if (chara?.ownerChara != null)
                return chara.ownerChara;
            if (chara is Ally && chara.content != null)
                return (Character)chara.content.ParticipantList().FirstOrDefault() ?? chara;
            return chara;
        }

        public bool IsEngagedWithSideOf(Player viewer)
        {
            ulong viewerParty = GetClaimPartyGroupId(viewer);
            ulong claim = GetClaimPartyGroupId();
            if (claim != 0 && claim == viewerParty)
                return true;
            if (currentLockedTarget == viewer.Id)
                return true;
            Character locked = target as Character;
            if (locked == null || locked.Id != currentLockedTarget)
                locked = CurrentArea?.FindActorInArea<Character>(currentLockedTarget);
            if (locked == null)
                return false;
            Character owner = GetCreditOwner(locked);
            if (owner == viewer)
                return true;
            return viewerParty != 0 && GetClaimPartyGroupId(owner) == viewerParty;
        }

        public void OnHateAdded(Character target)
        {
            if (!HasMonsterParty() || !IsAlive() || target == null)
                return;

            MonsterParty group = GetMonsterParty();
            if (group.occupancyGroupId != 0)
                return;

            ulong partyGroupId = GetClaimPartyGroupId(target);
            if (partyGroupId == 0)
            {
                if (npcWork.hateType == NpcWork.HATE_TYPE_UNCLAIMED)
                    SetHateType(NpcWork.HATE_TYPE_ENGAGED);
                return;
            }

            group.occupancyGroupId = partyGroupId;
            foreach (Player viewer in GetGroupViewers())
            {
                viewer.QueuePacket(group.BuildOccupancyPacket(viewer.Id, 0));
                viewer.QueuePacket(group.BuildOccupancyPacket(viewer.Id, partyGroupId));
            }
            SetHateType(NpcWork.HATE_TYPE_CLAIMED);
        }

        public void OnLinkHateAdded()
        {
            if (HasMonsterParty() && IsAlive() && npcWork.hateType == NpcWork.HATE_TYPE_UNCLAIMED)
                SetHateType(NpcWork.HATE_TYPE_ENGAGED);
        }

        public void OnHateListEmptied()
        {
            if (!HasMonsterParty() || enmityClearPending)
                return;
            if (!IsAlive())
                SetHateType(NpcWork.HATE_TYPE_DEAD);
            else
                ReleaseClaim(NpcWork.HATE_TYPE_UNCLAIMED);
        }

        public void ReleaseClaim(byte hateType)
        {
            if (monsterParty != null && monsterParty.occupancyGroupId != 0)
            {
                monsterParty.occupancyGroupId = 0;
                foreach (Player viewer in GetGroupViewers())
                    viewer.QueuePacket(monsterParty.BuildOccupancyPacket(viewer.Id, 0));
            }
            SetHateType(hateType);
        }

        private void SetHateType(byte hateType)
        {
            if (npcWork.hateType == hateType)
                return;
            npcWork.hateType = hateType;

            SubPacket packet = GetHateTypePacket(null);
            foreach (Player viewer in GetGroupViewers())
                viewer.QueuePacket(new SubPacket(packet, viewer.Id));
        }

        #region Enmity indicator (0x0195)

        private uint enmityIndicatorTarget;
        private readonly HashSet<uint> enmityIndicatorViewers = new HashSet<uint>();
        private readonly Dictionary<uint, ushort> enmityIndicatorSent = new Dictionary<uint, ushort>();
        private DateTime nextEnmityIndicatorRefresh = DateTime.MinValue;
        private bool enmityClearPending;

        public void FlushPendingEnmityClear()
        {
            if (!enmityClearPending)
                return;
            enmityClearPending = false;
            ClearEnmityIndicator();
            SetHateType(NpcWork.HATE_TYPE_DEAD);
        }

        public SubPacket GetEnmityIndicatorPacket(Player viewer)
        {
            if (IsAlive() && enmityIndicatorTarget != 0 && IsEnmityIndicatorRecipient(viewer))
            {
                enmityIndicatorViewers.Add(viewer.Id);
                ushort flag = GetEnmityIndicatorFlag(viewer);
                enmityIndicatorSent[viewer.Id] = flag;
                return SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, enmityIndicatorTarget, flag);
            }
            return SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, SetEnmityIndicatorPacket.NO_TARGET, SetEnmityIndicatorPacket.FLAG_NONE);
        }

        public void UpdateEnmityIndicator(Character newTarget)
        {
            if (newTarget == null || !IsAlive())
            {
                if (enmityClearPending)
                    return;
                ClearEnmityIndicator();
                return;
            }

            bool engaging = enmityIndicatorTarget == 0;
            enmityIndicatorTarget = newTarget.Id;
            foreach (Player viewer in GetGroupViewers())
            {
                if (!IsEnmityIndicatorRecipient(viewer))
                    continue;
                ushort flag = GetEnmityIndicatorFlag(viewer);
                if (engaging || !enmityIndicatorViewers.Contains(viewer.Id))
                    viewer.QueuePacket(SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, SetEnmityIndicatorPacket.NO_TARGET, flag));
                viewer.QueuePacket(SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, enmityIndicatorTarget, flag));
                enmityIndicatorViewers.Add(viewer.Id);
                enmityIndicatorSent[viewer.Id] = flag;
            }
        }

        private ushort GetEnmityIndicatorFlag(Player viewer)
        {
            if (hateContainer == null || !hateContainer.HasHateForTarget(viewer))
                return SetEnmityIndicatorPacket.FLAG_NONE;
            if (viewer.Id == enmityIndicatorTarget)
                return SetEnmityIndicatorPacket.FLAG_ENGAGED;
            var list = hateContainer.GetHateList();
            uint mine = list[viewer].cumulativeEnmity, top = 0;
            foreach (var entry in list.Values)
                if (entry.actor != null && entry.actor.Id == enmityIndicatorTarget)
                    top = entry.cumulativeEnmity;
            if (top == 0 || mine >= top)
                return SetEnmityIndicatorPacket.FLAG_ENGAGED;
            return (ushort)Math.Max(1, (int)(100L * mine / top));
        }

        private void RefreshEnmityIndicator(DateTime tick)
        {
            if (enmityIndicatorTarget == 0 || enmityClearPending || !IsAlive() || tick < nextEnmityIndicatorRefresh)
                return;
            nextEnmityIndicatorRefresh = tick.AddSeconds(1);
            foreach (Player viewer in GetGroupViewers())
            {
                if (!IsEnmityIndicatorRecipient(viewer))
                    continue;
                ushort flag = GetEnmityIndicatorFlag(viewer);
                if (enmityIndicatorSent.TryGetValue(viewer.Id, out ushort last) && last == flag)
                    continue;
                viewer.QueuePacket(SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, enmityIndicatorTarget, flag));
                enmityIndicatorViewers.Add(viewer.Id);
                enmityIndicatorSent[viewer.Id] = flag;
            }
        }

        public void ClearEnmityIndicator()
        {
            uint lastTarget = enmityIndicatorTarget != 0 ? enmityIndicatorTarget : SetEnmityIndicatorPacket.NO_TARGET;
            enmityIndicatorTarget = 0;
            enmityIndicatorSent.Clear();
            if (enmityIndicatorViewers.Count == 0)
                return;

            foreach (Player viewer in GetGroupViewers())
            {
                if (!enmityIndicatorViewers.Contains(viewer.Id))
                    continue;
                viewer.QueuePacket(SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, lastTarget, SetEnmityIndicatorPacket.FLAG_NONE));
                viewer.QueuePacket(SetEnmityIndicatorPacket.BuildPacket(Id, viewer.Id, SetEnmityIndicatorPacket.NO_TARGET, SetEnmityIndicatorPacket.FLAG_NONE));
            }
            enmityIndicatorViewers.Clear();
        }

        private bool IsEnmityIndicatorRecipient(Player viewer)
        {
            if (hateContainer != null && hateContainer.HasHateForTarget(viewer))
                return true;
            ulong claim = GetClaimPartyGroupId();
            return claim != 0 && GetClaimPartyGroupId(viewer) == claim;
        }

        #endregion

        private List<Player> GetGroupViewers()
        {
            List<Player> viewers = new List<Player>();
            if (CurrentArea == null)
                return viewers;
            foreach (Player player in CurrentArea.GetPlayers())
            {
                if (player.playerSession != null && player.playerSession.actorInstanceList.Contains(this))
                    viewers.Add(player);
            }
            return viewers;
        }

        #endregion

        public uint GetDetectionType()
        {
            return (uint)detectionType;
        }
        
        public void SetDetectionType(uint detectionType)
        {
            this.detectionType = (DetectionType)detectionType;
        }

        public override void Update(DateTime tick)
        {
            FlushPendingEnmityClear();
            RefreshEnmityIndicator(tick);
            if (!attached && !deferAttach)
                AttachBrain();
            this.aiContainer.Update(tick);
            this.statusEffects.Update(tick);
        }

        // Resolves the profile on the first update, so pool, genus and content are already set.
        public void AttachBrain(object profile = null, XLua.LuaTable overrides = null)
        {
            attached = true;
            deferAttach = false;
            if (!perception.Senses && !neutral)
                perception.FromDetectionType(detectionType);
            Brain?.Attach(profile, overrides);
        }

        public override void PostUpdate(DateTime tick, List<SubPacket> packets = null)
        {
            // todo: should probably add another flag for battleTemp since all this uses reflection
            packets = new List<SubPacket>();
            if ((updateFlags & ActorUpdateFlags.HpTpMp) != 0)
            {
                var propPacketUtil = new ActorPropertyPacketUtil("charaWork/stateAtQuicklyForAll", this);
                propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkill[0]");
                propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkillLevel");

                propPacketUtil.AddProperty("charaWork.battleTemp.castGauge_speed[0]");
                propPacketUtil.AddProperty("charaWork.battleTemp.castGauge_speed[1]");
                packets.AddRange(propPacketUtil.Done());
            }
            if (IsDead())
            {
                cadenceTarget = null;
                updateFlags &= ~ActorUpdateFlags.Position;
            }
            base.PostUpdate(tick, packets);
        }

        public override bool CanAttack()
        {
            // todo:
            return true;
        }

        public override bool CanUse(Character target, BattleCommand spell, CommandResult error = null)
        {
            // todo:
            if (target == null)
            {
                // Target does not exist.
                return false;
            }
            if (Utils.Distance(positionX, positionY, positionZ, target.positionX, target.positionY, target.positionZ) > spell.range)
            {
                // The target is out of range.
                return false;
            }
            if (!IsValidTarget(target, spell.mainTarget) || !spell.IsValidMainTarget(this, target))
            {
                // error packet is set in IsValidTarget
                return false;
            }
            return true;
        }

        public uint GetDespawnTime()
        {
            return despawnTime;
        }

        public void SetDespawnTime(uint seconds)
        {
            despawnTime = seconds;
        }

        public uint GetRespawnTime()
        {
            return respawnTime;
        }

        public void SetRespawnTime(uint seconds)
        {
            respawnTime = seconds;
        }

        // todo: create an action object?
        public bool OnAttack(AttackState state)
        {
            return false;
        }

        public override void Spawn(DateTime tick)
        {
            if (respawnTime > 0)
            {
                ForceRespawn();
            }
        }

        public void ForceRespawn()
        {
            base.Spawn(Program.Tick);

            this.isMovingToSpawn = false;
            this.hateContainer.ClearHate();
            if (monsterParty != null)
                monsterParty.occupancyGroupId = 0;
            npcWork.hateType = NpcWork.HATE_TYPE_UNCLAIMED;
            SendRespawnPackets();
            RecalculateStats();
            PartBreak.Reset(this);

            OnSpawn();
            if (attached)
                Brain?.Attach();
            updateFlags |= ActorUpdateFlags.AllNpc;
        }

        private void SendRespawnPackets()
        {
            foreach (Player player in CurrentArea.GetPlayers())
            {
                if (player.playerSession == null || !player.playerSession.actorInstanceList.Contains(this))
                    continue;
                player.QueuePackets(GetSpawnPackets(player, 0x01));
                player.QueuePackets(GetInitPackets());
            }
        }

        public override void Die(DateTime tick, CommandResultContainer actionContainer = null)
        {
            if (IsAlive())
            {
                // todo: does retail 
                if (lastAttacker?.ownerChara is Player)
                    lastAttacker = lastAttacker.ownerChara;

                if (lastAttacker is Player)
                {
                    //I think this is, or should be odne in DoBattleAction. Packet capture had the message in the same packet as an attack
                    // <actor> defeat/defeats <target>
                    if (actionContainer != null)
                        actionContainer.AddEXPAction(new CommandResult(Id, 30108, 0));

                    List<Player> expMembers = BattleUtils.GetExpEligibleMembers((Player)lastAttacker, this);
                    foreach (Player member in expMembers)
                        BattleUtils.AddBattleBonusEXP(member, this, actionContainer, expMembers.Count);

                    HashSet<Player> credited = new HashSet<Player>(expMembers) { (Player)lastAttacker };
                    foreach (Player member in credited)
                    {
                        try { member.HandleBNpcKill(GetActorClassId()); }
                        catch (Exception e) { Program.Log.Error("Quest kill hook failed: {0}", e); }
                    }
                }

                if (actionContainer != null)
                    enmityClearPending = true;
                else
                    ClearEnmityIndicator();

                EventBus.Raise(ActorEventType.Died, this, lastAttacker);

                if (positionUpdates != null)
                    positionUpdates.Clear();

                aiContainer.InternalDie(tick, despawnTime);
                //this.ResetMoveSpeeds();
                // todo: reset cooldowns

                lua.LuaEngine.GetInstance().OnSignal("mobkill");
            }
            else
            {
                var err = String.Format("[{0}][{1}] {2} {3} {4} {5} tried to die ded", Id, GetUniqueId(), positionX, positionY, positionZ, CurrentArea.GetName());
                Program.Log.Error(err);
                //throw new Exception(err);
            }
        }

        public override void Despawn(DateTime tick)
        {
            // todo: probably didnt need to make a new state...
            aiContainer.InternalDespawn(tick, respawnTime);
            EventBus.Raise(ActorEventType.Despawned, this);
            this.isAtSpawn = true;
        }

        public override void OnAttack(State state, CommandResult action, ref CommandResult error)
        {
            base.OnAttack(state, action, ref error);
            // todo: move this somewhere else prolly and change based on model/appearance (so maybe in Character.cs instead)
            action.animation = 0x11001000; // (temporary) wolf anim
        }

        public override void OnSpawn()
        {
            base.OnSpawn();
            EventBus.Raise(ActorEventType.Spawned, this);
        }

        public override void OnDespawn()
        {
            if (monsterParty != null)
                foreach (Player viewer in GetGroupViewers())
                    viewer.QueuePacket(monsterParty.BuildDeletePacket(viewer.Id));
            base.OnDespawn();
            // The move home is only for a respawn; without one it slides the corpse to its spawn point.
            if (respawnTime == 0)
            {
                ClearPositionUpdates();
                updateFlags &= ~ActorUpdateFlags.Position;
            }
        }

        public uint GetBattleNpcId()
        {
            return bnpcId;
        }

        public void SetBattleNpcId(uint id)
        {
            this.bnpcId = id;
        }

        public Int64 GetMobMod(MobModifier mobMod)
        {
            return GetMobMod((uint)mobMod);
        }

        public Int64 GetMobMod(uint mobModId)
        {
            Int64 res;
            if (mobModifiers.TryGetValue((MobModifier)mobModId, out res))
                return res;
            return 0;
        }

        public void SetMobMod(uint mobModId, Int64 val)
        {
            if (mobModifiers.ContainsKey((MobModifier)mobModId))
                mobModifiers[(MobModifier)mobModId] = val;
            else
                mobModifiers.Add((MobModifier)mobModId, val);
        }

        public override void OnDamageTaken(Character attacker, BattleCommand skill, CommandResult action,  CommandResultContainer actionContainer = null)
        {
            base.OnDamageTaken(attacker, skill, action, actionContainer);
        }
    }
}
