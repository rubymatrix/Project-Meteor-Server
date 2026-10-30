using System;
using System.Collections.Generic;

namespace Meteor.Map.DataObjects
{
    // One slot of the client's quest reward sheet (gamedata_quest_rewards). The client's reward
    // window reads the same sheet by quest id; the server picks which slots to list and supplies the
    // EXP figure.
    class QuestRewardSlot
    {
        public const int SLOT_COMPLETION = 100;   // listed and paid at completion
        public const int SLOT_MIDQUEST = 300;     // mid-quest payout (script pays it in its sequence)
        public const int SLOT_UNLOCK = 302;       // command unlock (-4) or optional item

        public const int KIND_GIL = -2;
        public const int KIND_ITEM_3 = -3;
        public const int KIND_COMMAND = -4;
        public const int KIND_ITEM_8 = -8;
        public const int KIND_ITEM = -10;
        public const int KIND_EXP = -12;          // amount = EXP
        public const int KIND_EXP_PERCENT = -13;  // amount = % of a level's EXP at the quest level
        public const int KIND_SEALS_ITEM = -14;   // targetId = a seal item
        public const int KIND_SEALS = -15;        // seals of the player's grand company
        public const int KIND_SKILL_EXP = -16;    // EXP % to skill `skill` (job quests)

        public readonly uint questId;
        public readonly int slot, slotType, kind, iconId, targetId, param, skill, questLevel;
        public readonly int[] amounts;

        public QuestRewardSlot(uint questId, int slot, int slotType, int kind, int iconId, int targetId, int param,
            int[] amounts, int skill, int questLevel)
        {
            this.questId = questId;
            this.slot = slot;
            this.slotType = slotType;
            this.kind = kind;
            this.iconId = iconId;
            this.targetId = targetId;
            this.param = param;
            this.amounts = amounts;
            this.skill = skill;
            this.questLevel = questLevel;
        }

        // Tier 1-4; a negative amount falls back to amount1, as the client does.
        public int GetAmount(int tier)
        {
            int i = Math.Max(1, Math.Min(4, tier)) - 1;
            return amounts[i] < 0 ? amounts[0] : amounts[i];
        }

        public bool IsExp()
        {
            return kind == KIND_EXP || kind == KIND_EXP_PERCENT || kind == KIND_SKILL_EXP;
        }

        public bool IsItem()
        {
            return kind == KIND_ITEM || kind == KIND_ITEM_8 || kind == KIND_ITEM_3 || kind == KIND_SEALS_ITEM;
        }
    }
}
