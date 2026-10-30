using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Attack spells from a level-typical Lv50 thaumaturge, without the random spread. Magnitudes and
    // the INT weight are the client command sheet's.
    [Collection("engines")]
    public sealed class DamageSpellTests
    {
        private const int Thaumaturge = 22;

        private readonly FormulaScript lua;

        public DamageSpellTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double Cast(int magnitude, int targetLevel, double? intel = null, double ampBonus = 0) =>
            lua.One("spellDamage", Thaumaturge, 50, magnitude, 0.5, targetLevel, intel, ampBonus);

        [Fact]
        public void FireOnEvenLevel()
        {
            double got = Cast(950, 50);
            Assert.True(got >= 284 && got <= 314,
                Sources.Cite("KAN-IV", $"Lv50 THM Fire on Lv50: retail 284-314, server {got}"));
        }

        [Fact]
        public void ThunderOnIfrit()
        {
            double got = Cast(1050, 58);
            Assert.True(got >= 221 && got <= 248,
                Sources.Cite("RCAP-IFRIT", $"Lv50 BLM Thunder on Ifrit L58: retail 221-248, server {got}"));
        }

        [Fact]
        public void IntelligenceGain()
        {
            double gain = (Cast(950, 50, 266) / Cast(950, 50, 198) - 1) * 100;
            Assert.True(gain >= 30 && gain <= 37,
                Sources.Cite("BG-110", $"INT 198 -> 266 at even level: retail +30-37%, server +{gain:F1}%"));
        }

        [Fact]
        public void DamagePerIntelligencePoint()
        {
            double intel = lua.One("typicalInt", Thaumaturge, 50);
            double perPoint = (Cast(950, 50, intel + 100) - Cast(950, 50, intel)) / 100;
            Assert.True(perPoint >= 1.17 * 0.8 && perPoint <= 1.17 * 1.2,
                Sources.Cite("BG-198", $"Lv50 Fire per +1 INT: retail 1.17 +-20%, server {perPoint:F2}"));
        }

        [Fact]
        public void DamagePerMagicPotencyPoint()
        {
            double perPoint = (Cast(950, 50, null, 100) - Cast(950, 50)) / 100;
            Assert.True(perPoint >= 2.2 * 0.8 && perPoint <= 2.2 * 1.2,
                Sources.Cite("BG-198", $"Lv50 Fire per +1 attack magic potency: retail 2.2 +-20%, server {perPoint:F2}"));
        }

        // Thunder 1050, Fire 950, Blizzard 800, Thundara 500.
        [Fact]
        public void DamageFollowsMagnitude()
        {
            double thunder = Cast(1050, 50), fire = Cast(950, 50), blizzard = Cast(800, 50), thundara = Cast(500, 50);
            Assert.True(thunder > fire && fire > blizzard && blizzard > thundara,
                Sources.Cite("CL-CMD", $"Thunder > Fire > Blizzard > Thundara by magnitude, server {thunder} / {fire} / {blizzard} / {thundara}"));
        }
    }
}
