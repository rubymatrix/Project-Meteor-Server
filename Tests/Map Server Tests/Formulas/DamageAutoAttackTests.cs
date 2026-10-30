using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Auto-attacks between level-typical characters, without the random spread.
    [Collection("engines")]
    public sealed class DamageAutoAttackTests
    {
        private const int Gladiator = 3;
        private const int Lancer = 8;

        private readonly FormulaScript lua;

        public DamageAutoAttackTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double Swing(int classId, int level, double damage, double delay, int mobLevel) =>
            lua.One("physicalDamage", "aa", 1.0, classId, level, damage, delay, 0, mobLevel, false,
                null, null, null, null, null);

        [Fact]
        public void DragoonOnIfrit()
        {
            double got = Swing(Lancer, 50, 127, 3.1, 58);
            Assert.True(got >= 14 && got <= 26,
                Sources.Cite("RCAP-IFRIT", $"Lv50 DRG, Garuda's Beak, on Ifrit L58: retail 14-26, server {got}"));
        }

        [Fact]
        public void DamagePerWeaponDamagePoint()
        {
            double perPoint = (Swing(Gladiator, 50, 100, 3.0, 50) - Swing(Gladiator, 50, 80, 3.0, 50)) / 20;
            Assert.True(perPoint >= 1.9 && perPoint <= 2.5,
                Sources.Cite("BG-P24", $"Lv50 auto-attack per +1 weapon Damage: retail 2.2 +-0.3, server {perPoint:F2}"));
        }
    }
}
