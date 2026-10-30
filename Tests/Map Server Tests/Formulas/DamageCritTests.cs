using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Critical hit rate (percent) and critical damage multiplier.
    [Collection("engines")]
    public sealed class DamageCritTests
    {
        private const int Gladiator = 3;
        private const int Marauder = 4;
        private const int Lancer = 8;
        private const int Thaumaturge = 22;

        private readonly FormulaScript lua;

        public DamageCritTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double PlayerRate(int classId, int level, int mobLevel, int rating = 0) =>
            lua.One("critRate", classId, level, true, 0, mobLevel, false, rating);

        private double MobRate(int mobLevel, int classId, int level) =>
            lua.One("critRate", 0, mobLevel, false, classId, level, true, 0);

        private double Multiplier(int level, int mobLevel, int potency = 0, bool magic = false, double? uncapped = null) =>
            lua.One("critMultiplier", level, mobLevel, potency, magic, uncapped);

        [Fact]
        public void EvenLevel()
        {
            double got = PlayerRate(Gladiator, 50, 50);
            Assert.True(got >= 6 && got <= 9, Sources.Cite("BG-261", $"Lv50 on Lv50: retail 7.5% +-1.5, server {got:F2}%"));
        }

        [Fact]
        public void FiveLevelsBelow()
        {
            double got = PlayerRate(Gladiator, 50, 45);
            Assert.True(got >= 10.2 && got <= 12.2, Sources.Cite("BG-P17", $"Lv50 on Lv45: retail 11.2% +-1, server {got:F2}%"));
        }

        [Fact]
        public void MagicFiveLevelsAbove()
        {
            double got = PlayerRate(Thaumaturge, 50, 55);
            Assert.True(got >= 4.5 && got <= 7.5, Sources.Cite("BG-P17", $"Lv50 Fire on Lv55: retail 6% +-1.5, server {got:F2}%"));
        }

        [Theory]
        [InlineData(50, 24.3)]
        [InlineData(40, 26.4)]
        public void HundredTwoRating(int mobLevel, double expected)
        {
            double got = PlayerRate(Gladiator, 50, mobLevel, 102);
            Assert.True(got >= expected - 1.5 && got <= expected + 1.5,
                Sources.Cite("BG-581", $"Lv50 on Lv{mobLevel}, +102 crit rating: retail {expected}% +-1.5, server {got:F2}%"));
        }

        [Fact]
        public void RatingSlope()
        {
            double perPoint = (PlayerRate(Gladiator, 50, 50, 72) - PlayerRate(Gladiator, 50, 50)) / 72;
            Assert.True(perPoint >= 0.13 && perPoint <= 0.19,
                Sources.Cite("BG-432", $"crit rate per rating point: retail 0.16 +-0.03, server {perPoint:F3}"));
        }

        [Fact]
        public void CapAboveTwentySix()
        {
            double got = PlayerRate(Gladiator, 50, 50, 500);
            Assert.True(got > 26, Sources.Cite("BG-570", $"crit rate cap: retail above 26%, server {got:F2}%"));
        }

        // Player auto-attacks on higher mobs: 1.5-7.7% pooled.
        [Theory]
        [InlineData(Gladiator, 27, 30)]
        [InlineData(Marauder, 26, 30)]
        [InlineData(Lancer, 50, 58)]
        [InlineData(Marauder, 50, 58)]
        public void PlayerOnHigherMob(int classId, int level, int mobLevel)
        {
            double got = PlayerRate(classId, level, mobLevel);
            Assert.True(got >= 1.5 && got <= 7.7,
                Sources.Cite("CAP-OUT", $"class {classId} Lv{level} on Lv{mobLevel}: retail 1.5-7.7%, server {got:F2}%"));
        }

        [Fact]
        public void IfritOnPlayers()
        {
            double got = MobRate(58, Lancer, 50);
            Assert.True(got < 4, Sources.Cite("RCAP-IFRIT", $"Ifrit L58 on Lv50: retail 0 in 70 (< 4%), server {got:F2}%"));
        }

        [Fact]
        public void MobOnLowerGladiator()
        {
            double got = MobRate(30, Gladiator, 27);
            Assert.True(got >= 5 && got <= 27, Sources.Cite("CAP-OUT", $"Lv30 mob on Lv27 GLA: retail 5-27%, server {got:F2}%"));
        }

        [Fact]
        public void MultiplierAtEvenLevel()
        {
            double got = Multiplier(50, 50);
            Assert.True(got >= 1.20 && got <= 1.23, Sources.Cite("KAN-IV", $"crit damage at dLVL 0: retail x1.20-1.23, server x{got:F3}"));
        }

        [Theory]
        [InlineData(4)]
        [InlineData(6)]
        [InlineData(8)]
        public void MultiplierFloor(int dlvl)
        {
            double got = Multiplier(50, 50 + dlvl);
            Assert.True(got >= 1.15, Sources.Cite("KAN-IV", $"crit damage at dLVL +{dlvl}: retail floor x1.15, server x{got:F3}"));
            if (dlvl > 4)
                Assert.True(got <= 1.15 + 1e-9, Sources.Cite("KAN-IV", $"crit damage at dLVL +{dlvl}: retail at the x1.15 floor, server x{got:F3}"));
        }

        [Theory]
        [InlineData(20)]
        [InlineData(35)]
        [InlineData(49)]
        public void MultiplierCap(int below)
        {
            double got = Multiplier(50, 50 - below);
            Assert.True(System.Math.Abs(got - 1.75) < 1e-9, Sources.Cite("KAN-IV", $"crit damage at dLVL -{below}: retail cap x1.75, server x{got:F3}"));
        }

        // Retail crit / normal pairs for a Lv26 marauder: 1.26 on a Lv25 mob, 1.27 on a Lv30 mob.
        [Theory]
        [InlineData(25, 1.26)]
        [InlineData(30, 1.27)]
        public void MarauderCritOverNormal(int mobLevel, double expected)
        {
            double got = Multiplier(26, mobLevel);
            Assert.True(got >= expected * 0.92 && got <= expected * 1.08,
                Sources.Cite("CAP-WS", $"Lv26 MRD crit / normal on Lv{mobLevel}: retail {expected} +-8%, server {got:F3}"));
        }

        [Fact]
        public void ComboCritCanPassCap()
        {
            double got = Multiplier(50, 1, 0, true, 175);
            Assert.True(got > 1.75, Sources.Cite("KAN-IV", $"Thundaga combo crit (+175 potency) far below: retail above x1.75, server x{got:F3}"));
        }

        [Fact]
        public void FloorAndCapAfterPotency()
        {
            double high = Multiplier(50, 1, 1000);
            double low = Multiplier(50, 58, -1000);
            Assert.True(System.Math.Abs(high - 1.75) < 1e-9 && System.Math.Abs(low - 1.15) < 1e-9,
                Sources.Cite("KAN-IV", $"crit damage clamps after potency: retail x1.15-1.75, server x{low:F3} / x{high:F3}"));
        }

        [Fact]
        public void SmallPotencyShowsNothingFiveLevelsUp()
        {
            double none = Multiplier(50, 55), some = Multiplier(50, 55, 15);
            Assert.True(some <= none + 1e-9,
                Sources.Cite("KAN-IV", $"+15 crit potency on Lv55 at Lv50: retail no gain below +16, server x{none:F3} -> x{some:F3}"));
        }

        // Crit damage points gained from +50 potency.
        [Theory]
        [InlineData(50, 7)]
        [InlineData(55, 6)]
        public void FiftyPotency(int mobLevel, double expected)
        {
            double gain = (Multiplier(50, mobLevel, 50) - Multiplier(50, mobLevel)) * 100;
            Assert.True(gain >= expected - 2 && gain <= expected + 2,
                Sources.Cite("BG-418", $"+50 crit potency on Lv{mobLevel}: retail +{expected} pts +-2, server +{gain:F1}"));
        }
    }
}
