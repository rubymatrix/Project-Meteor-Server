using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Level difference: spell level factor and the DEF slope against higher monsters.
    [Collection("engines")]
    public sealed class DamageLevelGapTests
    {
        private const int Gladiator = 3;

        private readonly FormulaScript lua;

        public DamageLevelGapTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        // A monster auto-attack on a Lv50 gladiator with this much DEF.
        private double MobSwing(int mobLevel, double defense) =>
            lua.One("physicalDamage", "aa", 1.0, 0, mobLevel, null, null, Gladiator, 50, true,
                null, null, null, defense, null);

        [Theory]
        [InlineData(-15, 3.7, 4.5)]
        [InlineData(-49, 6.0, 7.4)]
        public void SpellOnLowerTarget(int dlvl, double low, double high)
        {
            double ratio = lua.One("spellLevelFactor", dlvl) / lua.One("spellLevelFactor", 0);
            Assert.True(ratio >= low && ratio <= high,
                Sources.Cite("KAN-IV", $"Fire at dLVL {dlvl} / at dLVL 0: retail x{low}-{high}, server x{ratio:F2}"));
        }

        // Damage taken = D0 - k x effective DEF: k by how far the monster is above.
        [Theory]
        [InlineData(0, 0.227, 0.247)]
        [InlineData(2, 0.28, 0.31)]
        [InlineData(8, 0.516, 0.536)]
        [InlineData(9, 0.55, 0.58)]
        public void DefenseSlope(int dlvl, double low, double high)
        {
            double k = (MobSwing(50 + dlvl, 0) - MobSwing(50 + dlvl, 400)) / 400;
            Assert.True(k >= low && k <= high,
                Sources.Cite("KAN-III", $"damage per DEF from a monster {dlvl} levels up: retail {low}-{high}, server {k:F3}"));
        }

        [Theory]
        [InlineData(2000)]
        [InlineData(4000)]
        public void FloorFromHigherMonster(int defense)
        {
            double got = MobSwing(52, defense);
            Assert.True(got >= 35 && got <= 42,
                Sources.Cite("KAN-III", $"R52 on R50 with {defense} DEF: retail floor 35-42, server {got}"));
        }
    }
}
