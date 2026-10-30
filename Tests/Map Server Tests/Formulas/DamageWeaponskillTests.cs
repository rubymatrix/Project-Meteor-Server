using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Opening weaponskills (potency 1.0) between level-typical characters, without the random spread.
    [Collection("engines")]
    public sealed class DamageWeaponskillTests
    {
        private const int Gladiator = 3;
        private const int Marauder = 4;
        private const int Archer = 7;
        private const int Lancer = 8;

        private readonly FormulaScript lua;

        public DamageWeaponskillTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double Hit(string kind, int classId, int level, double damage, double delay, int mobLevel,
            double? primary = null, double? secondary = null) =>
            lua.One("physicalDamage", kind, 1.0, classId, level, damage, delay, 0, mobLevel, false,
                primary, secondary, null, null, null);

        [Fact]
        public void FastBlade()
        {
            double got = Hit("ws", Gladiator, 27, 26, 2.5, 30);
            Assert.True(got >= 56 && got <= 65,
                Sources.Cite("CAP-WS", $"Lv27 GLA Fast Blade on Lv30: retail 56-65, server {got}"));
        }

        [Fact]
        public void FastBladeOverAutoAttack()
        {
            double ratio = Hit("ws", Gladiator, 27, 26, 2.5, 30) / Hit("aa", Gladiator, 27, 26, 2.5, 30);
            Assert.True(ratio >= 2.5 && ratio <= 3.6,
                Sources.Cite("CAP-WS", $"Lv27 GLA Fast Blade / auto-attack on Lv30: retail 2.5-3.6, server {ratio:F2}"));
        }

        [Fact]
        public void HeavySwing()
        {
            double got = Hit("ws", Marauder, 26, 46, 4.2, 30);
            Assert.True(got >= 77 && got <= 106,
                Sources.Cite("CAP-WS", $"Lv26 MRD Heavy Swing on Lv30: retail 77-106, server {got}"));
        }

        [Fact]
        public void HeavySwingOverAutoAttack()
        {
            double ratio = Hit("ws", Marauder, 26, 46, 4.2, 30) / Hit("aa", Marauder, 26, 46, 4.2, 30);
            Assert.True(ratio >= 1.8 && ratio <= 2.1,
                Sources.Cite("CAP-WS", $"Lv26 MRD Heavy Swing / auto-attack on Lv30: retail 1.8-2.1, server {ratio:F2}"));
        }

        // Weaponskills key off DPS, auto-attacks off Damage: a fast sword gets more from a weaponskill.
        [Fact]
        public void FastWeaponGainsMoreFromWeaponskills()
        {
            double sword = Hit("ws", Gladiator, 27, 26, 2.5, 30) / Hit("aa", Gladiator, 27, 26, 2.5, 30);
            double axe = Hit("ws", Marauder, 26, 46, 4.2, 30) / Hit("aa", Marauder, 26, 46, 4.2, 30);
            Assert.True(sword > axe,
                Sources.Cite("JPF-49642", $"weaponskill / auto-attack: 2.5 s sword {sword:F2} must exceed 4.2 s axe {axe:F2}"));
        }

        // Stats above every cap, so only DPS changes.
        [Fact]
        public void DamagePerDps()
        {
            double low = Hit("ws", Archer, 50, 108, 3.0, 50, 400, 400);
            double high = Hit("ws", Archer, 50, 111, 3.0, 50, 400, 400);
            double perHundredth = (high - low) / 100;
            Assert.True(perHundredth >= 0.16 && perHundredth <= 0.26,
                Sources.Cite("BG-P24", $"Lv50 weaponskill per +0.01 DPS: retail 0.21 +-0.05, server {perHundredth:F3}"));
        }

        [Fact]
        public void TrueThrustOnIfrit()
        {
            double got = Hit("ws", Lancer, 50, 127, 3.1, 58);
            Assert.True(got >= 139 * 0.92 && got <= 139 * 1.08,
                Sources.Cite("RCAP-IFRIT", $"Lv50 DRG True Thrust on Ifrit L58: retail 139 +-8%, server {got}"));
        }

        [Fact]
        public void TrueThrustOverAutoAttackOnIfrit()
        {
            double ratio = Hit("ws", Lancer, 50, 127, 3.1, 58) / Hit("aa", Lancer, 50, 127, 3.1, 58);
            Assert.True(ratio >= 5 && ratio <= 6,
                Sources.Cite("RCAP-IFRIT", $"Lv50 DRG True Thrust / auto-attack on Ifrit L58: retail 5-6, server {ratio:F2}"));
        }

        // Weapon DPS; primary cap band (0 = not measured); secondary cap band.
        [Theory]
        [InlineData(34.62, 315, 320, 275, 280)]
        [InlineData(36.74, 330, 335, 295, 300)]
        [InlineData(39.70, 348, 350, 305, 310)]
        [InlineData(39.77, 348, 350, 305, 310)]
        [InlineData(40.0, 0, 0, 310, 312)]
        [InlineData(42.06, 0, 0, 317, 318)]
        public void WeaponskillStatCaps(double dps, int pLow, int pHigh, int sLow, int sHigh)
        {
            var caps = lua.Call("statCaps", "ws", dps);
            if (pHigh > 0)
                Assert.True(caps[0] >= pLow && caps[0] <= pHigh,
                    Sources.Cite("T-50219", $"primary cap at DPS {dps}: retail {pLow}-{pHigh}, server {caps[0]:F1}"));
            Assert.True(caps[1] >= sLow && caps[1] <= sHigh,
                Sources.Cite("T-50219", $"secondary cap at DPS {dps}: retail {sLow}-{sHigh}, server {caps[1]:F1}"));
        }
    }
}
