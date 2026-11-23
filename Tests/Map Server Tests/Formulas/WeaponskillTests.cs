using System;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Physical damage beyond the single captured auto-attack band in DamageTests.
    [Covers("formulas.levelFactor", "formulas.variance")]
    [Collection("engines")]
    public sealed class WeaponskillTests
    {
        private const int Gladiator = 3;

        private readonly FormulaScript lua;

        public WeaponskillTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        private double Hit(string kind, double potency, double damage, double delay, int level = 30, int mobLevel = 30) =>
            lua.One("hit", kind, potency, Gladiator, level, damage, delay, "", mobLevel, "");

        // Weaponskills follow DPS, auto-attacks follow Damage: with the same Damage a slower weapon
        // hits harder on auto-attack and softer on weaponskills.
        [Fact]
        public void WeaponskillsFollowDps()
        {
            double aaFast = Hit("aa", 1, 30, 2.5), aaSlow = Hit("aa", 1, 30, 4.0);
            double wsFast = Hit("ws", 1, 30, 2.5), wsSlow = Hit("ws", 1, 30, 4.0);
            Assert.True(aaSlow > aaFast, Sources.Cite("JPF-49642", $"auto-attack: fast {aaFast}, slow {aaSlow}"));
            Assert.True(wsSlow < wsFast, Sources.Cite("JPF-49642", $"weaponskill: fast {wsFast}, slow {wsSlow}"));
        }

        [Fact]
        public void PotencyScalesDamage()
        {
            double one = Hit("ws", 1, 30, 3.0), two = Hit("ws", 2, 30, 3.0);
            Assert.True(Math.Abs(two - 2 * one) <= 1, Sources.Cite("CODE-RATES", $"potency 1: {one}, potency 2: {two}"));
        }

        [Fact]
        public void NeverBelowOne()
        {
            Assert.True(Hit("aa", 1, 1, 3.0, level: 1, mobLevel: 60) >= 1, Sources.Cite("CODE-RATES", "Lv1 on Lv60"));
        }

        [Theory]
        [InlineData(-40, 1.5)]
        [InlineData(-10, 1.5)]
        [InlineData(-4, 1.2)]
        [InlineData(0, 1.0)]
        [InlineData(5, 0.65)]
        [InlineData(10, 0.3)]
        [InlineData(40, 0.3)]
        public void LevelFactor(int gap, double expected)
        {
            double got = lua.One("levelFactor", gap);
            Assert.True(Math.Abs(got - expected) < 1e-9, Sources.Cite("CAP-AA", $"gap {gap}: expected {expected}, got {got}"));
        }

        [Fact]
        public void PhysicalSpreadIsEightPercent()
        {
            var r = lua.Call("varianceRange", "physical", 5000);
            Assert.True(r[0] >= 0.92 && r[1] <= 1.08 && r[1] - r[0] > 0.15,
                Sources.Cite("CODE-RATES", $"spread {r[0]:F4}..{r[1]:F4}"));
        }
    }
}
