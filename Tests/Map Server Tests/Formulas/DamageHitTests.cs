using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Physical hit rate (percent) between level-typical characters.
    [Collection("engines")]
    public sealed class DamageHitTests
    {
        private const int Pugilist = 2;
        private const int Gladiator = 3;
        private const int Marauder = 4;
        private const int Lancer = 8;

        private readonly FormulaScript lua;

        public DamageHitTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double PlayerRate(int classId, int level, int mobLevel, int acc = 0, int dex = 0) =>
            lua.One("hitRate", classId, level, true, 0, mobLevel, false, acc, dex);

        private double MobRate(int mobLevel, int classId, int level) =>
            lua.One("hitRate", 0, mobLevel, false, classId, level, true, 0, 0);

        [Theory]
        [InlineData(Gladiator, 27, 30, 81, 98)]
        [InlineData(Marauder, 26, 30, 75, 97)]
        public void PlayerOnHigherLeveMob(int classId, int level, int mobLevel, double low, double high)
        {
            double got = PlayerRate(classId, level, mobLevel);
            Assert.True(got >= low && got <= high,
                Sources.Cite("CAP-OUT", $"class {classId} Lv{level} on Lv{mobLevel}: retail {low}-{high}%, server {got:F1}%"));
        }

        [Theory]
        [InlineData(Lancer)]
        [InlineData(Marauder)]
        public void PlayerOnIfrit(int classId)
        {
            // The retail party had Comradery.
            int comradery = (int)System.Math.Round(lua.One("comraderyAccuracy", 50));
            double got = PlayerRate(classId, 50, 58, comradery);
            Assert.True(got >= 79 && got <= 93,
                Sources.Cite("RCAP-IFRIT", $"class {classId} Lv50 on Ifrit L58: retail 79-93%, server {got:F1}%"));
        }

        [Theory]
        [InlineData(Gladiator, 27, 81, 99)]
        [InlineData(Marauder, 26, 46, 95)]
        public void LeveMobOnLowerPlayer(int classId, int level, double low, double high)
        {
            double got = MobRate(30, classId, level);
            Assert.True(got >= low && got <= high,
                Sources.Cite("CAP-OUT", $"Lv30 mob on class {classId} Lv{level}: retail {low}-{high}%, server {got:F1}%"));
        }

        [Fact]
        public void IfritOnPlayers()
        {
            double got = MobRate(58, Lancer, 50);
            Assert.True(got >= 88 && got <= 99, Sources.Cite("RCAP-IFRIT", $"Ifrit L58 on Lv50: retail 88-99%, server {got:F1}%"));
        }

        [Theory]
        [InlineData(0, 0)]
        [InlineData(17, 3)]
        public void CapNearHundred(int acc, int dex)
        {
            double got = PlayerRate(Pugilist, 50, 45, acc, dex);
            Assert.True(got >= 99.8 && got <= 99.97,
                Sources.Cite("BG-521", $"Lv50 PGL on Lv45, +{acc} ACC +{dex} DEX: retail 99.8-99.97%, server {got:F2}%"));
        }

        [Fact]
        public void DexterityAndAccuracyFourLevelsUp()
        {
            double control = PlayerRate(Pugilist, 50, 54);
            double dex = PlayerRate(Pugilist, 50, 54, 0, 35) - control;
            double acc = PlayerRate(Pugilist, 50, 54, 34, 0) - control;
            Assert.True(dex >= 3 && dex <= 7, Sources.Cite("BG-P8", $"+35 DEX on Lv54: retail +5 pts +-2, server +{dex:F1}"));
            Assert.True(acc >= 6.5 && acc <= 10.5, Sources.Cite("BG-P8", $"+34 ACC on Lv54: retail +8.5 pts +-2, server +{acc:F1}"));
        }
    }
}
