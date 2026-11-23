using System;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // The level curves in stats.lua between their sourced anchors.
    [Covers("stats.baseHp", "stats.baseMp", "stats.referenceWeaponDamage", "stats.mobMp", "stats.mobIsCaster",
        "stats.mobExpected", "stats.compatibility", "stats.itemFactor")]
    [Collection("engines")]
    public sealed class CurveTests
    {
        private readonly FormulaScript lua;

        public CurveTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // HP, MP, attack, DEF and weapon Damage never fall as a level is gained.
        [Theory]
        [InlineData(2)]
        [InlineData(3)]
        [InlineData(4)]
        [InlineData(7)]
        [InlineData(8)]
        [InlineData(22)]
        [InlineData(23)]
        public void NothingFallsWithLevel(int classId)
        {
            string[] names = { "HP", "MP", "attack", "DEF", "weapon Damage", "monster MP", "caster MP" };
            var prev = lua.Call("curves", classId, 1);
            for (int level = 2; level <= 50; level++)
            {
                var cur = lua.Call("curves", classId, level);
                for (int i = 0; i < names.Length; i++)
                    Assert.True(cur[i] >= prev[i], Sources.Cite("CODE-STATS", $"class {classId} {names[i]} Lv{level - 1} {prev[i]} -> Lv{level} {cur[i]}"));
                prev = cur;
            }
        }

        [Theory]
        [InlineData(10)]
        [InlineData(30)]
        [InlineData(50)]
        public void CastersHaveFiveTimesTheMp(int level)
        {
            var c = lua.Call("curves", 0, level);
            // Both are floored from the same curve value.
            Assert.True(c[6] >= 5 * c[5] && c[6] < 5 * (c[5] + 1), Sources.Cite("CODE-STATS", $"Lv{level}: {c[5]} and {c[6]}"));
        }

        [Theory]
        [InlineData(22, 0, true)]
        [InlineData(23, 0, true)]
        [InlineData(0, 3, true)]
        [InlineData(0, 0, false)]
        [InlineData(3, 0, false)]
        public void WhoIsACaster(int classId, int spellList, bool expected)
        {
            bool got = lua.One("mobIsCaster", classId, spellList) != 0;
            Assert.True(got == expected, Sources.Cite("CODE-STATS", $"class {classId} spell list {spellList}: {got}"));
        }

        [Fact]
        public void MonsterExpectedIsClassless()
        {
            var r = lua.Call("mobExpectedDef", 40);
            Assert.True(r[0] == r[1], Sources.Cite("CODE-STATS", $"{r[0]} vs {r[1]}"));
        }

        [Theory]
        [InlineData(1.0)]
        [InlineData(0.6)]
        [InlineData(0.0)]
        public void CompatibilityScalesGear(double value)
        {
            Assert.True(lua.One("compatibility", value) == value, Sources.Cite("CL-COMPAT", $"{value}"));
        }

        [Fact]
        public void BrokenGearGivesNothing()
        {
            Assert.True(lua.One("itemFactor", 20, 25, true) == 0, Sources.Cite("PN119-I", "broken"));
            double whole = lua.One("itemFactor", 20, 25, false);
            Assert.True(whole == lua.One("levelAdjust", 20, 25), Sources.Cite("CL-ITEMLVL", $"whole {whole}"));
        }
    }
}
