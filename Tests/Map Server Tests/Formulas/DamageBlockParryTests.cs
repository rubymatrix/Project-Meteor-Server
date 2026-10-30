using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Block and parry rates (percent) and block damage reduction.
    [Collection("engines")]
    public sealed class DamageBlockParryTests
    {
        private const int Pugilist = 2;
        private const int Gladiator = 3;
        private const int Marauder = 4;
        private const int Lancer = 8;

        private readonly FormulaScript lua;

        public DamageBlockParryTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double Parry(int mobLevel, int classId, int level, bool shield = false, int parry = 0, double? dex = null) =>
            lua.One("parryRate", mobLevel, false, classId, level, true, shield, parry, dex);

        private double Block(int mobLevel, int classId, int level, int dexBonus = 0, int blockRate = 0) =>
            lua.One("blockRate", mobLevel, false, classId, level, true, true, dexBonus, blockRate);

        private double Reduction(int mobLevel, int vitBonus = 0, int block = 0) =>
            lua.One("blockReduction", mobLevel, Gladiator, 50, vitBonus, block) * 100;

        [Fact]
        public void ShieldDecidesBlockOrParry()
        {
            double parry = Parry(50, Gladiator, 50, true);
            double block = lua.One("blockRate", 50, false, Gladiator, 50, true, false, 0, 0);
            Assert.True(parry == 0, Sources.Cite("CAP-OUT", $"shielded player parry: retail never, server {parry:F1}%"));
            Assert.True(block == 0, Sources.Cite("T-27048", $"unshielded player block: retail never, server {block:F1}%"));
        }

        [Fact]
        public void MonstersNeverBlockOrParry()
        {
            double parry = lua.One("parryRate", 27, true, 0, 30, false, false, 0, null);
            double block = lua.One("blockRate", 27, true, 0, 30, false, true, 0, 0);
            Assert.True(parry == 0 && block == 0,
                Sources.Cite("CAP-OUT", $"Lv30 mob defending: retail 0 parries and 0 blocks in 81, server {parry:F1}% / {block:F1}%"));
        }

        [Fact]
        public void LeveMobOnShieldedGladiator()
        {
            double got = Block(30, Gladiator, 27);
            Assert.True(got >= 17 && got <= 45, Sources.Cite("CAP-OUT", $"Lv30 mob on shielded Lv27 GLA: retail 17-45% blocked, server {got:F1}%"));
        }

        [Fact]
        public void BlockRatePerPoint()
        {
            double baseline = Block(50, Gladiator, 50);
            double perDex = (Block(50, Gladiator, 50, 100) - baseline) / 100;
            double perBlockRate = (Block(50, Gladiator, 50, 0, 100) - baseline) / 100;
            double cap = Block(50, Gladiator, 50, 0, 1000);
            Assert.True(perDex >= 0.07 && perDex <= 0.13, Sources.Cite("BG-439", $"block rate per DEX: retail 0.1 +-0.03, server {perDex:F3}"));
            Assert.True(perBlockRate >= 0.17 && perBlockRate <= 0.23, Sources.Cite("BG-439", $"block rate per Block Rate: retail 0.2 +-0.03, server {perBlockRate:F3}"));
            Assert.True(cap == 75, Sources.Cite("BG-439", $"block rate cap: retail 75%, server {cap:F1}%"));
        }

        [Fact]
        public void BlockReductionPerPoint()
        {
            double baseline = Reduction(50);
            double perVit = (Reduction(50, 100) - baseline) / 100;
            double perBlock = (Reduction(50, 0, 100) - baseline) / 100;
            Assert.True(perVit >= 0.07 && perVit <= 0.13, Sources.Cite("BG-439", $"block reduction per VIT: retail 0.1 pts +-0.03, server {perVit:F3}"));
            Assert.True(perBlock >= 0.17 && perBlock <= 0.23, Sources.Cite("BG-439", $"block reduction per Block: retail 0.2 pts +-0.03, server {perBlock:F3}"));
        }

        [Fact]
        public void BlockReductionClamp()
        {
            double high = Reduction(50, 0, 1000);
            double low = Reduction(80);
            Assert.True(System.Math.Abs(high - 75) < 1e-9 && System.Math.Abs(low - 20) < 1e-9,
                Sources.Cite("BG-439", $"block reduction clamp: retail 20-75%, server {low:F1}% to {high:F1}%"));
        }

        // Lv50 gladiator's Block; the mob's level; the share removed.
        [Theory]
        [InlineData(28, 52, 63.6)]
        [InlineData(71, 52, 68.8)]
        [InlineData(120, 52, 72.7)]
        [InlineData(28, 58, 19.5)]
        [InlineData(120, 58, 15.2)]
        public void BlockReductionByLevel(int block, int mobLevel, double expected)
        {
            double got = Reduction(mobLevel, 0, block);
            Assert.True(got >= expected - 5 && got <= expected + 5,
                Sources.Cite("BG-312", $"Block {block} vs R{mobLevel}: retail -{expected}% +-5, server -{got:F1}%"));
        }

        [Fact]
        public void LeveMobOnMarauder()
        {
            double got = Parry(30, Marauder, 26);
            Assert.True(got >= 2 && got <= 45, Sources.Cite("CAP-OUT", $"Lv30 mob on Lv26 MRD: retail 2-45% parried, server {got:F1}%"));
        }

        [Fact]
        public void IfritOnPlayers()
        {
            double got = Parry(58, Lancer, 50);
            Assert.True(got >= 0.3 && got <= 10, Sources.Cite("RCAP-IFRIT", $"Ifrit L58 on Lv50: retail 0.3-10% parried, server {got:F1}%"));
        }

        [Fact]
        public void PugilistOnLowerMob()
        {
            double got = Parry(45, Pugilist, 50);
            Assert.True(got >= 4.0 && got <= 7.2, Sources.Cite("BG-521", $"R45 on Lv50 PGL: retail 5.5-5.7% +-1.5 parried, server {got:F1}%"));
        }

        [Fact]
        public void ParryGearOnHigherMob()
        {
            double got = Parry(55, Pugilist, 50, false, 41, 301);
            Assert.True(got >= 1 && got <= 6, Sources.Cite("T-36877", $"Lv55 on Lv50, +41 Parry, 301 DEX: retail 1-6% parried, server {got:F1}%"));
        }
    }
}
