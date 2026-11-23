using System;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    [Covers("formulas.effectiveDefense", "formulas.defenseReduction", "formulas.levelGapDefense")]
    [Collection("engines")]
    public sealed class DefenseTests
    {
        private readonly FormulaScript lua;

        public DefenseTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // A level-typical defender takes 25% less from DEF.
        [Theory]
        [InlineData(3, 10, true)]
        [InlineData(3, 30, true)]
        [InlineData(23, 50, true)]
        [InlineData(0, 30, false)]
        [InlineData(0, 70, false)]
        public void TypicalDefenderCutsAQuarter(int classId, int level, bool isPlayer)
        {
            double cut = lua.Call("defense", classId, level, isPlayer, "")[1];
            Assert.True(Math.Abs(cut - 0.25) < 1e-9, Sources.Cite("KAN-III", $"class {classId} Lv{level}: cut {cut}"));
        }

        [Fact]
        public void MoreDefenseCutsMore()
        {
            double typical = lua.Call("defense", 3, 30, true, "")[1];
            double more = lua.Call("defense", 3, 30, true, "Defense=200")[1];
            Assert.True(more > typical && more < 1, Sources.Cite("KAN-III", $"cut {typical} -> {more}"));
        }

        [Fact]
        public void LevelGapDefenseStartsAfterFourLevels()
        {
            for (int gap = 0; gap <= 4; gap++)
                Assert.True(lua.One("levelGapDefense", 30, 30 + gap, "") == 0, Sources.Cite("CODE-RATES", $"+{gap}: none"));
            double last = 0;
            for (int gap = 5; gap <= 12; gap++)
            {
                double d = lua.One("levelGapDefense", 30, 30 + gap, "");
                Assert.True(d > last, Sources.Cite("CODE-RATES", $"+{gap}: {d} after {last}"));
                last = d;
            }
        }
    }
}
