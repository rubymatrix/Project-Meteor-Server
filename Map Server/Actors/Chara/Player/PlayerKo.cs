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
using Meteor.Map.actors.chara.ai;
using Meteor.Map.lua;
using Meteor.Map.packets.send;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.utils;

namespace Meteor.Map.Actors
{
    // KO and raise. A KO'd player stays dead until they Return or accept a raise. The client only
    // enters dead mode (Return, raise prompt) on a real 0 -> 1 main-state change after its scene is
    // up, so a player who logs in or zones in dead spawns passive in their own view and the death is
    // replayed once the zone-in finishes. Revives give Weakness through Player.lua onRevived.
    partial class Player
    {
        public bool pendingDeathReplay = false;
        private DateTime deathReplayAt = DateTime.MaxValue;
        // Return revives on arrival, so that zone-in keeps the KO and skips the replay.
        private bool skipDeathReplayOnce = false;

        // A raise shows as system command 24306 (ConfirmRaiseCommand) while
        // variableCommandConfirmRaise is 40000..40003; 40004 hides it. SenderByID stays 0: the prompt
        // formats the sender as a string and the client throws on a number.
        public static int RaiseOfferVariation = 40003;
        public static int RaiseOfferSeconds = 300;
        // No battle commands for 7 s after a raise.
        public const int RaiseCommandLockSeconds = 7;
        private DateTime raiseCommandLockUntil = DateTime.MinValue;
        private int raiseOfferHpPercent;
        private bool raiseOfferWeakness;
        private DateTime raiseOfferExpires = DateTime.MaxValue;

        public bool IsRaiseLocked()
        {
            return DateTime.Now < raiseCommandLockUntil;
        }

        private void UpdateKo(DateTime tick)
        {
            if (pendingDeathReplay && !isZoneChanging && tick >= deathReplayAt)
                ReplayDeathAfterZoneIn(tick);

            if (tick >= raiseOfferExpires)
            {
                ClearRaiseOffer();
                SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM, "", "The raise offer has expired.");
            }
        }

        // Login (saved dead, spawned passive): HP 0 and the normal Die(). Zone-in while dead (the
        // server kept the player dead): the same packets to this player only, with no second KO.
        public void ReplayDeathAfterZoneIn(DateTime tick)
        {
            pendingDeathReplay = false;
            deathReplayAt = DateTime.MaxValue;

            if (IsDead())
            {
                QueuePacket(SetActorStatePacket.BuildPacket(Id, currentMainState, 0));
                QueuePacket(CommandResultX00Packet.BuildPacket(Id, 0x72000062, 0));
                QueuePacket(CommandResultX01Packet.BuildPacket(Id, 0x7C000062, 21001, new CommandResult(Id, 0, 1)));
                var propPacketUtil = new ActorPropertyPacketUtil("charaWork/stateAtQuicklyForAll", this);
                propPacketUtil.AddProperty("charaWork.parameterSave.hp[0]");
                propPacketUtil.AddProperty("charaWork.parameterSave.hpMax[0]");
                propPacketUtil.AddProperty("charaWork.parameterSave.mp");
                propPacketUtil.AddProperty("charaWork.parameterSave.mpMax");
                propPacketUtil.AddProperty("charaWork.parameterTemp.tp");
                QueuePackets(propPacketUtil.Done());
                // A raise offered before the client was in dead mode: show the prompt again.
                if (HasRaiseOffer())
                    SendConfirmRaiseGroup();
            }
            else
            {
                charaWork.parameterSave.hp[0] = 0;
                updateFlags |= ActorUpdateFlags.HpTpMp;
                Die(tick);
            }
            SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM, "", "You are KO'd. Select Return from the main menu to return to your home point.");
        }

        public void SkipNextDeathReplay()
        {
            skipDeathReplayOnce = true;
        }

        public bool HasRaiseOffer()
        {
            return playerWork.variableCommandConfirmRaise != 0;
        }

        // Offers a raise; the player accepts through ConfirmRaiseCommand.
        public bool OfferRaise(Character sender, int hpPercent, bool weakness = true)
        {
            if (!IsDead())
                return false;

            raiseOfferHpPercent = hpPercent;
            raiseOfferWeakness = weakness;
            raiseOfferExpires = DateTime.Now.AddSeconds(RaiseOfferSeconds);

            playerWork.variableCommandConfirmRaise = RaiseOfferVariation;
            playerWork.variableCommandConfirmRaiseSenderByID = 0;
            playerWork.variableCommandConfirmRaiseSender = sender?.DisplayName ?? sender?.Name ?? "";
            playerWork.variableCommandConfirmRaiseSenderSex = sender is Player p ? p.GetSex() : (byte)0;
            SendConfirmRaiseGroup();
            return true;
        }

        // The raise light on this corpse, for raises with no real cast (GM). Never from the corpse
        // itself: a dead actor's result never finishes in the client and the player can't get up.
        public void PlayRaiseCastEffect(Character caster)
        {
            if (caster == null || caster == this || caster.IsDead())
                return;
            CurrentArea?.BroadcastPacketAroundActor(this,
                CommandResultX01Packet.BuildPacket(caster.Id, 0x01001094, 27349, new CommandResult(Id, 30354, 1, 0, 0, 1)));
        }

        public bool AcceptRaise()
        {
            if (!HasRaiseOffer())
                return false;

            int hpPercent = raiseOfferHpPercent;
            bool weakness = raiseOfferWeakness;
            ClearRaiseOffer();

            if (!IsDead())
                return false;

            Revive(hpPercent);
            // "<name> regains consciousness", from the revived player after its state change.
            BroadcastPacket(CommandResultX01Packet.BuildPacket(Id, 0x01001066, 0,
                new CommandResult(Id, 30109, 0x30100102, (ushort)Math.Max(0, (int)GetHP()), 1, 1)), true);
            raiseCommandLockUntil = DateTime.Now.AddSeconds(RaiseCommandLockSeconds);
            LuaEngine.CallLuaPlayerFunction(this, "onRevived", this, "raise", weakness);
            return true;
        }

        public void ClearRaiseOffer()
        {
            raiseOfferExpires = DateTime.MaxValue;
            if (!HasRaiseOffer())
                return;

            playerWork.variableCommandConfirmRaise = 0;
            playerWork.variableCommandConfirmRaiseSenderByID = 0;
            playerWork.variableCommandConfirmRaiseSender = "";
            playerWork.variableCommandConfirmRaiseSenderSex = 0;
            SendConfirmRaiseGroup();
        }

        public void SendConfirmRaiseGroup()
        {
            var propPacketUtil = new ActorPropertyPacketUtil("playerWork/confirmRaiseCommand", this);
            propPacketUtil.AddProperty("playerWork.variableCommandConfirmRaise");
            propPacketUtil.AddProperty("playerWork.variableCommandConfirmRaiseSenderByID");
            propPacketUtil.AddProperty("playerWork.variableCommandConfirmRaiseSender");
            propPacketUtil.AddProperty("playerWork.variableCommandConfirmRaiseSenderSex");
            QueuePackets(propPacketUtil.Done());
        }

        // 0 male, 1 female, by tribe.
        public byte GetSex()
        {
            switch (playerWork.tribe)
            {
                case 2: case 5: case 7: case 9: case 11: case 12: case 13:
                    return 1;
                default:
                    return 0;
            }
        }

        // Any revive (raise, Return, GM) drops a pending death replay and raise offer.
        public override void Revive(int hpPercent = 100)
        {
            pendingDeathReplay = false;
            deathReplayAt = DateTime.MaxValue;
            skipDeathReplayOnce = false;
            base.Revive(hpPercent);
            ClearRaiseOffer();
        }
    }
}
