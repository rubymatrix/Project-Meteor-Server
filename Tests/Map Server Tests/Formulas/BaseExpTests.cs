using System;
using Meteor.Map.actors.chara.ai.utils;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    public sealed class BaseExpTests
    {
        [Theory]
        [InlineData(5)]
        [InlineData(20)]
        [InlineData(45)]
        public void EvenMatchIsTheTableValue(int level)
        {
            int got = BattleUtils.GetBaseEXP(level, level);
            Assert.True(got == BattleUtils.BASEEXP[level - 1], Sources.Cite("CODE-EXP", $"Lv{level}: {got}"));
        }

        [Fact]
        public void TwentyLevelsBelowGivesNothing()
        {
            Assert.True(BattleUtils.GetBaseEXP(40, 20) == 0, Sources.Cite("CODE-EXP", "Lv20 monster for Lv40"));
            Assert.True(BattleUtils.GetBaseEXP(40, 30) > 0, Sources.Cite("CODE-EXP", "Lv30 monster for Lv40"));
        }

        [Fact]
        public void HigherMonstersNeverGiveLess()
        {
            int last = 0;
            for (int mob = 11; mob <= 50; mob++)
            {
                int got = BattleUtils.GetBaseEXP(30, mob);
                Assert.True(got >= last, Sources.Cite("CODE-EXP", $"Lv{mob}: {got} after {last}"));
                last = got;
            }
        }

        // The bonus for a higher monster stops at a cap set by the lower of the two levels.
        [Theory]
        [InlineData(5, 1.5)]
        [InlineData(15, 2.0)]
        [InlineData(25, 2.5)]
        [InlineData(35, 3.0)]
        public void LevelBonusCap(int level, double cap)
        {
            int got = BattleUtils.GetBaseEXP(level, level + 30);
            int expected = (int)(BattleUtils.BASEEXP[level - 1] * cap);
            Assert.True(got == expected, Sources.Cite("EL-EXP", $"Lv{level} far below: expected {expected}, got {got}"));
        }

        [Fact]
        public void PartyShareApplies()
        {
            int solo = BattleUtils.GetBaseEXP(30, 30, 1), duo = BattleUtils.GetBaseEXP(30, 30, 2);
            Assert.True(duo == (int)(BattleUtils.BASEEXP[29] * 0.75), Sources.Cite("EL-EXP", $"solo {solo}, two {duo}"));
        }
    }
}
