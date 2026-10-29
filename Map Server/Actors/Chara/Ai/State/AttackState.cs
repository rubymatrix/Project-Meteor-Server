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
using Meteor.Common;
using Meteor.Map.Actors;
using Meteor.Map.DataObjects;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.battle;
namespace Meteor.Map.actors.chara.ai.state
{
    class AttackState : State
    {
        private DateTime attackTime;
        private const int RETRY_MS = 500;
        private const float HEIGHT_LIMIT = 5.0f;
        private const double RANGE_MESSAGE_SECONDS = 3.0;
        private DateTime lastRangeMessage = DateTime.MinValue;

        public AttackState(Character owner, Character target) :
            base(owner, target)
        {
            this.canInterrupt = false;
            this.startTime = DateTime.Now;

            owner.ChangeState(SetActorStatePacket.MAIN_STATE_ACTIVE);
            ChangeTarget(target);
            attackTime = startTime;
            owner.aiContainer.mover?.Stop();
        }

        public override void OnStart()
        {

        }

        public override bool Update(DateTime tick)
        {
            if ((target == null || owner.target != target || owner.target?.Id != owner.currentLockedTarget) && owner.isAutoAttackEnabled)
                owner.aiContainer.ChangeTarget(target = owner.CurrentArea.FindActorInArea<Character>(owner.currentTarget));

            if (target == null || target.IsDead())
            {
                if (owner.IsMonster() || owner.IsAlly())
                    target = ((BattleNpc)owner).hateContainer.GetMostHatedTarget();
            }
            else
            {
                if (IsAttackReady())
                {
                    if (CanAttack())
                    {
                        TryInterrupt();

                        // todo: check weapon delay/haste etc and use that
                        if (!interrupt)
                        {
                            OnComplete();
                        }
                        else
                        {

                        }
                        SetInterrupted(false);
                    }
                    else
                    {
                        attackTime = DateTime.Now.AddMilliseconds(RETRY_MS);
                        return false;
                    }
                    attackTime = DateTime.Now.AddMilliseconds(owner.GetAttackDelayMs());
                }
            }
            return false;
        }

        public override void OnInterrupt()
        {
            // todo: send paralyzed/sleep message etc.
            if (errorResult != null)
            {
                owner.CurrentArea.BroadcastPacketAroundActor(owner, CommandResultX01Packet.BuildPacket(errorResult.targetId, errorResult.animation, 0x765D, errorResult));
                errorResult = null;
            }
        }

        public override void OnComplete()
        {
            //BattleAction action = new BattleAction(target.actorId, 0x765D, (uint) HitEffect.Hit, 0, (byte) HitDirection.None);
            errorResult = null;

            // todo: implement auto attack damage bonus in Character.OnAttack
            /*
              ≪Auto-attack Damage Bonus≫
              Class        Bonus 1       Bonus 2
              Pugilist     Intelligence  Strength
              Gladiator    Mind          Strength
              Marauder     Vitality      Strength
              Archer       Dexterity     Piety
              Lancer       Piety         Strength
              Conjurer     Mind          Piety
              Thaumaturge  Mind          Piety
              * The above damage bonus also applies to “Shot” attacks by archers.
             */
            // handle paralyze/intimidate/sleep/whatever in Character.OnAttack


            // todo: Change this to use a BattleCommand like the other states

            //List<BattleAction> actions = new List<BattleAction>();
            CommandResultContainer actions = new CommandResultContainer();

            //This is all temporary until the skill sheet is finishd and the different auto attacks are added to the database
            //Some mobs have multiple unique auto attacks that they switch between as well as ranged auto attacks, so we'll need a way to handle that
            //For now, just use a temporary hardcoded BattleCommand that's the same for everyone.
            BattleCommand attackCommand = new BattleCommand(22104, "Attack");
            attackCommand.range = owner.GetAttackRange();
            attackCommand.rangeHeight = 10;
            attackCommand.worldMasterTextId = 0x765D;
            attackCommand.mainTarget = (ValidTarget)768;
            attackCommand.validTarget = (ValidTarget)17152;
            attackCommand.commandType = CommandType.AutoAttack;
            attackCommand.numHits = (byte)owner.GetMod(Modifier.HitCount);
            attackCommand.basePotency = 100;
            ActionProperty property = (owner.GetMod(Modifier.AttackType) != 0) ? (ActionProperty)owner.GetMod(Modifier.AttackType) : WeaponProperty(owner);
            attackCommand.actionProperty = property;
            attackCommand.actionType = ActionType.Physical;

            uint anim = (17 << 24 | 1 << 12);

            if (owner is Player || owner is Ally)
                anim = (25 << 24 | 1 << 12);

            attackCommand.battleAnimation = anim;

            if (owner.CanUse(target, attackCommand))
            {
                attackCommand.targetFind.FindWithinArea(target, attackCommand.validTarget, attackCommand.aoeTarget);
                owner.DoBattleCommand(attackCommand, "autoattack");
            }
        }

        public override void TryInterrupt()
        {
            if (owner.statusEffects.HasStatusEffectsByFlag((uint)StatusEffectFlags.PreventAttack))
            {
                // todo: sometimes paralyze can let you attack, calculate proc rate
                var list = owner.statusEffects.GetStatusEffectsByFlag((uint)StatusEffectFlags.PreventAttack);
                uint statusId = 0;
                if (list.Count > 0)
                {
                    statusId = list[0].GetStatusId();
                }
                interrupt = true;
                return;
            }

            interrupt = !CanAttack();
        }

        private static ActionProperty WeaponProperty(Character owner)
        {
            if (owner is Player player)
            {
                var item = player.GetEquipment()?.GetItemAtSlot(Player.SLOT_MAINHAND);
                if (item != null && Server.GetItemGamedata(item.itemId) is WeaponItem weapon && weapon.damageAttributeType1 > 0)
                    return (ActionProperty)weapon.damageAttributeType1;
            }
            return ActionProperty.Slashing;
        }

        private bool IsAttackReady()
        {
            // todo: this enforced delay should really be changed if it's not retail..
            return Program.Tick >= attackTime && Program.Tick >= owner.aiContainer.GetLastActionTime();
        }

        private bool CanAttack()
        {
            if (!owner.isAutoAttackEnabled || Meteor.Map.AI.Factions.IsFriendly(target, owner))
            {
                return false;
            }

            if (target == null)
            {
                return false;
            }

            // todo: shouldnt need to check if owner is dead since all states would be cleared
            if (owner.IsDead() || target.IsDead())
            {
                if (owner.IsMonster() || owner.IsAlly())
                    ((BattleNpc)owner).hateContainer.ClearHate(target);

                owner.aiContainer.ChangeTarget(null);
                return false;
            }
            else if (!owner.IsValidTarget(target, ValidTarget.Enemy) || !owner.aiContainer.GetTargetFind().CanTarget(target, false, true))
            {
                return false;
            }
            // todo: use a mod for melee range
            else if (Utils.XZDistance(owner.positionX, owner.positionZ, target.positionX, target.positionZ) > owner.GetAttackRange()
                || Math.Abs(owner.positionY - target.positionY) > HEIGHT_LIMIT)
            {
                if (owner is Player && (DateTime.Now - lastRangeMessage).TotalSeconds >= RANGE_MESSAGE_SECONDS)
                {
                    lastRangeMessage = DateTime.Now;
                    //The target is too far away
                    ((Player)owner).SendGameMessage(Server.GetWorldManager().GetActor(), 32537, 0x20);
                }
                return false;
            }
            return true;
        }

        public override void Cleanup()
        {
            if (owner.IsDead())
                owner.Disengage();
        }

        public override bool CanChangeState()
        {
            return true;
        }
    }
}
