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
using Meteor.Map.Actors;
using Meteor.Map.packets.send.actor.battle;

namespace Meteor.Map.actors.chara.ai.state
{
    class State
    {
        protected Character owner;
        protected Character target;

        protected bool canInterrupt;
        protected bool interrupt = false;

        protected DateTime startTime;

        protected CommandResult errorResult;

        protected bool isCompleted;
        // Set once the readies result went out: only then does an interrupt need its own result.
        protected bool readied;

        public State(Character owner, Character target)
        {
            this.owner = owner;
            this.target = target;
            this.canInterrupt = true;
            this.interrupt = false;
        }

        public virtual bool Update(DateTime tick) { return true; }
        public virtual void OnStart() {  }
        public virtual void OnInterrupt() { }
        public virtual void OnComplete() { isCompleted = true; }
        public virtual bool CanChangeState() { return false; }
        public virtual void TryInterrupt() { }

        public virtual void Cleanup() { }

        // Chant byte (0x0144) for a cast's readies, by the command's castType: 2 THM/BLM, 3 CNJ/WHM,
        // 0x0B-0x10 monster moves. Other cast types pass their own fallback.
        private static readonly Dictionary<byte, byte> CHANT_BY_CAST_TYPE = new Dictionary<byte, byte>
        {
            { 0x02, 0x50 }, { 0x03, 0x60 },
            { 0x0B, 0xF0 }, { 0x0C, 0xE0 }, { 0x0D, 0xD0 }, { 0x0E, 0xC0 }, { 0x0F, 0xB0 }, { 0x10, 0xA0 },
        };

        protected static byte ChantFor(byte castType, byte fallback)
        {
            return CHANT_BY_CAST_TYPE.TryGetValue(castType, out byte chant) ? chant : fallback;
        }

        // Sent at once, right before the action result it goes with: the client applies a chant only
        // when the actor's next action result lands. Unchanged chants aren't resent, since each one
        // restarts the idle motion.
        protected void SendChant(byte chant)
        {
            if (owner.GetSubState().chantId == chant)
                return;
            owner.GetSubState().chantId = chant;
            owner.CurrentArea?.BroadcastPacketAroundActor(owner, owner.CreateSubStatePacket());
            owner.updateFlags &= ~ActorUpdateFlags.SubState;
        }

        // A monster's readied move or spell that is interrupted (stun, sleep, lost target) shows it with
        // an empty result from the monster: no text and no TP spent, since TP is paid when a move goes off.
        private const uint MONSTER_INTERRUPT_ANIMATION = 0x7F000063;

        protected void SendMonsterInterrupt(ushort commandId)
        {
            if (owner is Player || target == null || !readied)
                return;
            var result = new CommandResult(target.Id, 0, 0);
            result.animation = MONSTER_INTERRUPT_ANIMATION;
            owner.DoBattleAction(commandId, result.animation, result);
        }

        public bool CanInterrupt()
        {
            return canInterrupt;
        }

        public void SetInterrupted(bool interrupt)
        {
            this.interrupt = interrupt;
        }

        public bool IsCompleted()
        {
            return isCompleted;
        }

        public void ChangeTarget(Character target)
        {
            this.target = target;
        }

        public Character GetTarget()
        {
            return target;
        }

    }
}
