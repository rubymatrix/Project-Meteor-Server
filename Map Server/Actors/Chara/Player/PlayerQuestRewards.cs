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
using Meteor.Map.actors.chara.player;
using Meteor.Map.DataObjects;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.utils;

namespace Meteor.Map.Actors
{
    // Quest rewards from the client's reward sheet. Completion slots are paid when the quest completes;
    // mid-quest payouts are left to the quest scripts.
    partial class Player
    {
        private const ushort TEXT_REWARD_OBTAIN = 25047, TEXT_INVENTORY_FULL = 60022, TEXT_LEARN_COMMAND = 33926;
        private const uint ITEM_GIL = 1000001, ITEM_SEALS_BASE = 1000200;
        public const int COMMAND_PARLEY = 29497;

        // The completion slots the client's reward window lists, in slot order.
        public int[] GetQuestRewardSlots(uint questId)
        {
            var slots = new List<int>();
            foreach (QuestRewardSlot r in Server.GetQuestRewards(questId))
                if (r.slotType == QuestRewardSlot.SLOT_COMPLETION)
                    slots.Add(r.slot);
            return slots.ToArray();
        }

        // The EXP the reward window prints and completion pays.
        public int GetQuestRewardExp(uint questId, int tier = 1)
        {
            int total = 0;
            foreach (QuestRewardSlot r in Server.GetQuestRewards(questId))
                if (r.slotType == QuestRewardSlot.SLOT_COMPLETION && r.IsExp())
                    total += QuestRewardExp(r, tier);
            return total;
        }

        // Kind -12 pays the amount; -13 and -16 pay that percentage of a level's EXP at the quest's level.
        private int QuestRewardExp(QuestRewardSlot r, int tier)
        {
            int amount = r.GetAmount(tier);
            if (amount <= 0)
                return 0;
            if (r.kind == QuestRewardSlot.KIND_EXP)
                return amount;
            int level = r.questLevel > 0 ? r.questLevel : GetLevel();
            level = Math.Max(1, Math.Min(MAXEXP.Length, level));
            return (int)Math.Ceiling(MAXEXP[level - 1] * amount / 100.0);
        }

        private uint QuestRewardItem(QuestRewardSlot r)
        {
            if (r.kind == QuestRewardSlot.KIND_GIL)
                return ITEM_GIL;
            if (r.kind == QuestRewardSlot.KIND_SEALS)
                return gcCurrent >= 1 && gcCurrent <= 3 ? ITEM_SEALS_BASE + gcCurrent : 0;
            if (r.IsItem())
                return (uint)r.targetId;
            return 0;
        }

        public bool HasQuestRewardSheetRow(uint questId)
        {
            return Server.GetQuestRewards(questId).Count > 0;
        }

        public bool HasRoomForQuestRewards(uint questId, int tier = 1)
        {
            var items = new List<KeyValuePair<uint, int>>();
            foreach (QuestRewardSlot r in Server.GetQuestRewards(questId))
                if (r.slotType == QuestRewardSlot.SLOT_COMPLETION)
                    items.Add(new KeyValuePair<uint, int>(QuestRewardItem(r), r.GetAmount(tier)));
            return HasRoomForItemList(items);
        }

        // A script's own reward list: { { itemId, quantity }, ... }.
        public bool HasRoomForItems(XLua.LuaTable items)
        {
            var list = new List<KeyValuePair<uint, int>>();
            if (items != null)
            {
                for (int i = 1; i <= items.Length; i++)
                {
                    var entry = items.Get<int, XLua.LuaTable>(i);
                    if (entry == null)
                        continue;
                    uint id = (uint)entry.Get<int, double>(1);
                    double qty = entry.Get<int, double>(2);
                    list.Add(new KeyValuePair<uint, int>(id, qty > 0 ? (int)qty : 1));
                    entry.Dispose();
                }
            }
            return HasRoomForItemList(list);
        }

        // New stacks per package must fit its free slots; part of a quantity may top up a stack first.
        private bool HasRoomForItemList(List<KeyValuePair<uint, int>> items)
        {
            var newSlots = new Dictionary<ushort, int>();
            foreach (var pair in items)
            {
                uint item = pair.Key;
                int qty = pair.Value;
                if (item == 0 || qty <= 0)
                    continue;
                ushort pkgId = GetPackageForItem(item);
                ItemPackage pkg = GetItemPackage(pkgId);
                if (pkg == null)
                    return false;
                int maxStack = Math.Max(1, (int)(Server.GetItemGamedata(item)?.maxStack ?? 1));
                InventoryItem stack = pkg.GetItemByCatelogId(item);
                if (stack != null && stack.quality == 1)
                    qty -= Math.Max(0, maxStack - stack.quantity);
                if (qty <= 0)
                    continue;
                newSlots.TryGetValue(pkgId, out int n);
                newSlots[pkgId] = n + (qty + maxStack - 1) / maxStack;
            }
            foreach (var kv in newSlots)
                if (GetItemPackage(kv.Key).GetFreeSlots() < kv.Value)
                    return false;
            return true;
        }

        // One script reward item with the "You obtain" line. Returns the package result code.
        public int GiveRewardItem(uint itemId, int quantity)
        {
            ItemPackage pkg = GetItemPackage(GetPackageForItem(itemId));
            int result = pkg != null ? pkg.AddItem(itemId, quantity, 1) : ItemPackage.ERROR_SYSTEM;
            if (result == ItemPackage.ERROR_SUCCESS)
                SendGameMessage(Server.GetWorldManager().GetActor(), TEXT_REWARD_OBTAIN, 0x20, quantity, (int)itemId, 1);
            else
                Program.Log.Warn("Script reward {0} x{1} not given to {2} (error {3})", itemId, quantity, GetName(), result);
            return result;
        }

        // Pays the completion slots: EXP to the current class (or the slot's skill), gil, items and seals,
        // plus every command unlock. Scripts check HasRoomForQuestRewards before completing.
        public void GrantQuestRewards(uint questId, int tier = 1)
        {
            List<QuestRewardSlot> rewards = Server.GetQuestRewards(questId);
            if (rewards.Count == 0)
                return;

            Actor worldMaster = Server.GetWorldManager().GetActor();
            foreach (QuestRewardSlot r in rewards)
            {
                if (r.kind == QuestRewardSlot.KIND_COMMAND)
                {
                    GrantCommandUnlock(r.targetId, true);
                    continue;
                }
                if (r.slotType != QuestRewardSlot.SLOT_COMPLETION)
                    continue;

                if (r.IsExp())
                {
                    int exp = QuestRewardExp(r, tier);
                    byte classId = r.kind == QuestRewardSlot.KIND_SKILL_EXP && r.skill > 0 ? (byte)r.skill : (byte)GetClass();
                    if (exp > 0 && classId > 0)
                        DoBattleAction(0, 0, AddExp(exp, classId, 0));
                    continue;
                }

                uint item = QuestRewardItem(r);
                int qty = r.GetAmount(tier);
                if (item == 0 || qty <= 0)
                    continue;
                ItemPackage pkg = GetItemPackage(GetPackageForItem(item));
                int result = pkg != null ? pkg.AddItem(item, qty, 1) : ItemPackage.ERROR_SYSTEM;
                if (result == ItemPackage.ERROR_SUCCESS)
                    SendGameMessage(worldMaster, TEXT_REWARD_OBTAIN, 0x20, qty, (int)item, 1);
                else
                {
                    if (result == ItemPackage.ERROR_FULL)
                        SendGameMessage(worldMaster, TEXT_INVENTORY_FULL, 0x20);
                    Program.Log.Warn("Quest {0} reward {1} x{2} not given to {3} (error {4})", questId, item, qty, GetName(), result);
                }
            }
        }

        // Parley is gated by the negotiation flag; any other command below 30000 is a commandAcquired bit
        // at id - 26001. Returns false and sends nothing when it is already unlocked.
        public bool GrantCommandUnlock(int commandId, bool send)
        {
            string property, syncTarget = "charaWork/command";
            if (commandId == COMMAND_PARLEY)
            {
                if (charaWork.battleSave.negotiationFlag[0])
                    return false;
                charaWork.battleSave.negotiationFlag[0] = true;
                property = "charaWork.battleSave.negotiationFlag[0]";
                syncTarget = "charaWork/battleStateForSelf";
            }
            else
            {
                int index = commandId - 26001;
                if (index < 0 || index >= charaWork.commandAcquired.Length || charaWork.commandAcquired[index])
                    return false;
                charaWork.commandAcquired[index] = true;
                property = String.Format("charaWork.commandAcquired[{0}]", index);
            }

            if (send)
            {
                ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil(syncTarget, this);
                propPacketUtil.AddProperty(property);
                QueuePackets(propPacketUtil.Done());
                DoBattleAction(0, 0, new List<CommandResult> { new CommandResult(Id, TEXT_LEARN_COMMAND, 0, (ushort)commandId) });
            }
            return true;
        }
    }
}
