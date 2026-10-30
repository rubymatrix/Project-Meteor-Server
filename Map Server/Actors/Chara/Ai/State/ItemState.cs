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
using Meteor.Map.Actors;
using Meteor.Map.actors.chara.player;
using Meteor.Map.DataObjects;
using Meteor.Map.lua;
using Meteor.Map.packets.send.actor.battle;

namespace Meteor.Map.actors.chara.ai.state
{
    // Using a consumable (command 21007): food, potions and ethers, medicine, status cures and
    // scripted items. Effects come from server_items_consumable; duration and recast from
    // gamedata_items. Everything but scripted items is self only. The client shows no item recast,
    // so the server refuses with 32544.
    class ItemState : State
    {
        public const ushort COMMAND_USE_ITEM = 21007;
        public const ushort TEXT_CANNOT_USE_ITEM = 32544;
        private const ushort TEXT_USE_RECOVER_HP = 30320;
        private const ushort TEXT_USE_RECOVER_MP = 30321;
        private const ushort TEXT_USE_STATUS = 30330;
        private const ushort TEXT_USE_REMOVE = 30331;
        public const uint ANIM_USE_ITEM = 0x05FA3078;

        new Player owner;
        private readonly ushort package;
        private readonly ushort slot;
        private readonly uint itemId;
        private ConsumableData consumable;
        private ItemData itemData;
        private readonly Character requestedTarget;
        private static string ItemsScriptPath => ConfigConstants.OPTIONS_SCRIPTPATH + "/Battle/Items.lua";

        public ItemState(Player owner, Character target, ushort slot, uint itemId) : this(owner, target, ItemPackage.NORMAL, slot, itemId)
        {
        }

        public ItemState(Player owner, Character target, ushort package, ushort slot, uint itemId) :
            base(owner, target)
        {
            this.owner = owner;
            this.target = owner;
            requestedTarget = target ?? owner;
            this.package = package;
            this.slot = slot;
            this.itemId = itemId;
            startTime = DateTime.Now;

            // Using an item on a battle npc hands it over (feeding a caravan chocobo).
            if (target != null && target != owner && target.Brain != null)
            {
                Meteor.Map.AI.EventBus.Raise(new Meteor.Map.AI.ActorEvent(Meteor.Map.AI.ActorEventType.ItemGiven, target, owner) { ActionId = itemId });
                interrupt = true;
                return;
            }

            ushort error = Validate();
            if (error != 0)
            {
                owner.SendGameMessage(Server.GetWorldManager().GetActor(), error, 0x20, (object)(int)COMMAND_USE_ITEM);
                interrupt = true;
            }
        }

        private ushort Validate()
        {
            InventoryItem item = owner.GetItemPackage(package)?.GetItemAtSlot(slot);
            if (item == null || item.itemId != itemId)
                return TEXT_CANNOT_USE_ITEM;
            itemData = Server.GetItemGamedata(itemId);
            consumable = ConsumableData.Get(itemId);
            if (itemData == null || consumable == null || !consumable.IsSupported() || !owner.IsAlive())
                return TEXT_CANNOT_USE_ITEM;
            if (owner.GetItemRecastRemaining(itemData.recastGroup) > 0)
                return TEXT_CANNOT_USE_ITEM;
            if (consumable.type == ConsumableData.TYPE_SCRIPT)
            {
                // items.validate returns 0 or the refusal text; nothing is used up on a refusal.
                target = requestedTarget;
                int error = LuaEngine.CallLuaScriptFileFunctionForInt(ItemsScriptPath, "items.validate", TEXT_CANNOT_USE_ITEM, owner, requestedTarget, itemId);
                if (error != 0)
                    return (ushort)error;
            }
            return 0;
        }

        public override bool Update(DateTime tick)
        {
            if (interrupt)
                return true;
            OnComplete();
            return true;
        }

        public override void OnComplete()
        {
            isCompleted = true;
            ushort validateError = Validate();
            if (validateError != 0)
            {
                owner.SendGameMessage(Server.GetWorldManager().GetActor(), validateError, 0x20, (object)(int)COMMAND_USE_ITEM);
                return;
            }

            ItemPackage itemPackage = owner.GetItemPackage(package);
            CommandResultContainer results = new CommandResultContainer();
            switch (consumable.type)
            {
                case ConsumableData.TYPE_RESTORE:
                    foreach (ConsumableData.Effect effect in consumable.effects)
                    {
                        if (effect.modifier == (uint)Modifier.Hp)
                        {
                            int amount = Math.Min(effect.Compute(owner.GetMaxHP()), owner.GetMaxHP() - owner.GetHP());
                            owner.AddHP(amount);
                            results.AddAction(new CommandResult(owner.Id, TEXT_USE_RECOVER_HP, 0, (ushort)Math.Max(0, amount)));
                        }
                        else if (effect.modifier == (uint)Modifier.Mp)
                        {
                            int amount = Math.Min(effect.Compute(owner.GetMaxMP()), owner.GetMaxMP() - owner.GetMP());
                            owner.AddMP(amount);
                            results.AddAction(new CommandResult(owner.Id, TEXT_USE_RECOVER_MP, 0, (ushort)Math.Max(0, amount)));
                        }
                    }
                    break;

                case ConsumableData.TYPE_FOOD:
                case ConsumableData.TYPE_MEDICINE:
                    if (consumable.statusId != 0)
                    {
                        StatusEffect status = Server.GetWorldManager().GetStatusEffect(consumable.statusId);
                        if (status != null)
                        {
                            // The status script sizes its stat layer from the item id.
                            status.SetMagnitude(itemId);
                            status.SetDuration((uint)Math.Max(1, itemData.effectDuration));
                            status.SetOwner(owner);
                            owner.statusEffects.AddStatusEffect(status, owner, results, TEXT_USE_STATUS);
                        }
                    }
                    if (consumable.type == ConsumableData.TYPE_MEDICINE)
                        LuaEngine.CallLuaModuleFunction(ItemsScriptPath, "items.onMedicine", owner, itemId, results);
                    break;

                case ConsumableData.TYPE_SCRIPT:
                    LuaEngine.CallLuaModuleFunction(ItemsScriptPath, "items.use", owner, requestedTarget, itemId, results);
                    break;

                case ConsumableData.TYPE_CURE:
                    foreach (uint statusId in consumable.removeStatus)
                        owner.statusEffects.RemoveStatusEffect(statusId, results, TEXT_USE_REMOVE);
                    break;
            }

            itemPackage.RemoveItemAtSlot(slot, 1);
            owner.SetItemRecast(itemData.recastGroup, itemData.recastTime);

            results.CombineLists();
            var list = results.GetList();
            if (list.Count == 0)
                list.Add(new CommandResult(owner.Id, 0, 0));
            // One X01 per entry, since only X01 carries the item id; the motion plays once.
            uint anim = ANIM_USE_ITEM;
            foreach (CommandResult result in list)
            {
                owner.CurrentArea?.BroadcastPacketAroundActor(owner, CommandResultX01Packet.BuildPacket(owner.Id, anim, COMMAND_USE_ITEM, result, itemId));
                anim = Character.ANIM_MESSAGE_ONLY;
            }
        }
    }
}
