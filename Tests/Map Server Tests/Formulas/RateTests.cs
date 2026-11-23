using System;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Hit, crit, parry and block. The bases and slopes are our own choice, so these check the
    // shape: values at an even match, slopes, clamps, and who can parry or block.
    [Covers("formulas.hitRate", "formulas.critRate", "formulas.critMultiplier", "formulas.parryRate",
        "formulas.blockRate", "formulas.blockReduction", "formulas.clamp")]
    [Collection("engines")]
    public sealed class RateTests
    {
        private const string Source = "CODE-RATES";
        private const int Gladiator = 3;

        private readonly FormulaScript lua;

        public RateTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // Player (Gladiator) attacking a monster: hit, crit, crit multiplier, parry, block, block reduction.
        private double[] PlayerOnMob(int level, int mobLevel, string mods = "") =>
            lua.Call("rates", Gladiator, level, true, mods, 0, mobLevel, false, "");

        private double[] MobOnPlayer(int mobLevel, int level, string mods = "") =>
            lua.Call("rates", 0, mobLevel, false, "", Gladiator, level, true, mods);

        private static void Near(double expected, double got, string what) =>
            Assert.True(Math.Abs(expected - got) < 1e-9, Sources.Cite(Source, $"{what}: expected {expected}, got {got}"));

        [Fact]
        public void EvenMatch()
        {
            var p = PlayerOnMob(30, 30);
            Near(95, p[0], "player hit");
            Near(7.5, p[1], "crit");
            Near(1.21, p[2], "crit multiplier");
            Near(87, MobOnPlayer(30, 30)[0], "monster hit");
        }

        [Fact]
        public void HitFallsFasterPastFourLevels()
        {
            for (int gap = 0; gap < 12; gap++)
            {
                double step = PlayerOnMob(30, 30 + gap)[0] - PlayerOnMob(30, 31 + gap)[0];
                Near(gap < 4 ? 1.5 : 4.5, step, $"hit lost going from +{gap} to +{gap + 1} levels");
            }
        }

        [Fact]
        public void HitStaysInBounds()
        {
            Near(5, PlayerOnMob(10, 50)[0], "far stronger monster");
            Near(99.9, PlayerOnMob(50, 10)[0], "far weaker monster");
            Near(99.9, PlayerOnMob(30, 30, "Accuracy=200")[0], "huge accuracy");
        }

        [Fact]
        public void AccuracyAndDexterityRaiseHit()
        {
            double baseHit = PlayerOnMob(30, 34)[0];
            Near(baseHit + 2.5, PlayerOnMob(30, 34, "Accuracy=10")[0], "10 accuracy");
            Near(baseHit + 1.4, PlayerOnMob(30, 34, "Dexterity=10")[0], "10 DEX");
            Near(87 - 2.5, MobOnPlayer(30, 30, "Evasion=10")[0], "10 evasion on the player");
        }

        [Fact]
        public void CritRatingAndBounds()
        {
            Near(7.5 + 1.6, PlayerOnMob(30, 30, "CriticalHitRating=10")[1], "10 crit rating");
            Near(30, PlayerOnMob(30, 30, "CriticalHitRating=1000")[1], "crit cap");
            Near(1, PlayerOnMob(10, 50)[1], "crit floor");
            Assert.True(PlayerOnMob(30, 35)[1] < PlayerOnMob(30, 30)[1], Sources.Cite(Source, "crit falls against higher monsters"));
        }

        [Fact]
        public void CritMultiplierBounds()
        {
            for (int gap = -40; gap <= 40; gap += 5)
            {
                double m = PlayerOnMob(50, Math.Clamp(50 + gap, 1, 90))[2];
                Assert.True(m >= 1.15 && m <= 1.75, Sources.Cite(Source, $"gap {gap}: multiplier {m}"));
            }
        }

        [Fact]
        public void MonstersNeitherParryNorBlock()
        {
            var p = PlayerOnMob(30, 30);
            Near(0, p[3], "monster parry");
            Near(0, p[4], "monster block");
        }

        // Test Coverage row GLA-02: with a shield you block, without one you parry.
        [Fact]
        public void ShieldBlocksNoShieldParries()
        {
            var bare = MobOnPlayer(30, 30);
            Near(13, bare[3], "parry without shield");
            Near(0, bare[4], "block without shield");
            var shield = MobOnPlayer(30, 30, "CanBlock=1");
            Near(0, shield[3], "parry with shield");
            Near(20, shield[4], "block with shield");
            Near(0.45, shield[5], "block reduction");
        }

        [Fact]
        public void BlockReductionBounds()
        {
            Near(0.75, MobOnPlayer(10, 50, "CanBlock=1;Block=1000")[5], "reduction cap");
            Near(0.2, MobOnPlayer(50, 10, "CanBlock=1")[5], "reduction floor");
        }
    }
}
