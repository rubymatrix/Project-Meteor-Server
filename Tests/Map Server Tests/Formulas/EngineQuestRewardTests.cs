using Meteor.Map.DataObjects;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Reading the client's quest reward sheet: which amount a tier pays and what each slot kind is.
    public sealed class EngineQuestRewardTests
    {
        private static QuestRewardSlot Slot(int kind, params int[] amounts) =>
            new QuestRewardSlot(110001, 2, QuestRewardSlot.SLOT_COMPLETION, kind, 0, 8090201, 0, amounts, 0, 1);

        [Theory]
        [InlineData(1, 1000)]
        [InlineData(2, 2000)]
        [InlineData(4, 4000)]
        public void EachTierPaysItsOwnAmount(int tier, int expected)
        {
            int got = Slot(QuestRewardSlot.KIND_GIL, 1000, 2000, 3000, 4000).GetAmount(tier);
            Assert.True(got == expected, Sources.Cite("CL-QREWARD", $"tier {tier}: {expected}, got {got}"));
        }

        [Fact]
        public void ANegativeTierAmountPaysTheFirst()
        {
            int got = Slot(QuestRewardSlot.KIND_GIL, 200, -1, -1, -1).GetAmount(3);
            Assert.True(got == 200, Sources.Cite("CL-QREWARD", $"tier 3 with no amount of its own: 200, got {got}"));
        }

        [Theory]
        [InlineData(QuestRewardSlot.KIND_EXP, true, false)]
        [InlineData(QuestRewardSlot.KIND_EXP_PERCENT, true, false)]
        [InlineData(QuestRewardSlot.KIND_SKILL_EXP, true, false)]
        [InlineData(QuestRewardSlot.KIND_ITEM, false, true)]
        [InlineData(QuestRewardSlot.KIND_ITEM_8, false, true)]
        [InlineData(QuestRewardSlot.KIND_ITEM_3, false, true)]
        [InlineData(QuestRewardSlot.KIND_SEALS_ITEM, false, true)]
        [InlineData(QuestRewardSlot.KIND_GIL, false, false)]
        [InlineData(QuestRewardSlot.KIND_COMMAND, false, false)]
        public void SlotKinds(int kind, bool exp, bool item)
        {
            var s = Slot(kind, 1, -1, -1, -1);
            Assert.True(s.IsExp() == exp && s.IsItem() == item,
                Sources.Cite("CL-QREWARD", $"kind {kind}: EXP {exp}, item {item}; got EXP {s.IsExp()}, item {s.IsItem()}"));
        }
    }
}
