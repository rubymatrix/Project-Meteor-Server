using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Physical damage taken against DEF and VIT.
    [Collection("engines")]
    public sealed class DamageDefenseTests
    {
        private const int Gladiator = 3;

        private readonly FormulaScript lua;

        public DamageDefenseTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        private double MobHit(string kind, double potency, double defense) =>
            lua.One("physicalDamage", kind, potency, 0, 50, null, null, Gladiator, 50, true,
                null, null, null, defense, null);

        [Fact]
        public void EffectiveDefense()
        {
            double perVit = (lua.One("effectiveDefense", Gladiator, 50, 500, 300) - lua.One("effectiveDefense", Gladiator, 50, 500, 200)) / 100;
            double perDef = (lua.One("effectiveDefense", Gladiator, 50, 600, 200) - lua.One("effectiveDefense", Gladiator, 50, 500, 200)) / 100;
            Assert.True(perVit >= 0.64 && perVit <= 0.67, Sources.Cite("KAN-III", $"effective DEF per VIT: retail 0.64-0.67, server {perVit:F3}"));
            Assert.True(System.Math.Abs(perDef - 1) < 1e-9, Sources.Cite("KAN-III", $"effective DEF per DEF: retail 1, server {perDef:F3}"));
        }

        // 250 damage at 0 DEF becomes about 155 at 400 DEF and 60 at 800.
        [Theory]
        [InlineData(400, 155)]
        [InlineData(800, 60)]
        public void WorkedExample(int defense, double expected)
        {
            double got = 250 * MobHit("aa", 10, defense) / MobHit("aa", 10, 0);
            Assert.True(got >= expected * 0.95 && got <= expected * 1.05,
                Sources.Cite("KAN-III", $"Lv50 hit of 250 at 0 DEF, with {defense} DEF: retail {expected} +-5%, server {got:F0}"));
        }

        [Fact]
        public void SameSlopeForAutoAttacksAndWeaponskills()
        {
            double aa = (MobHit("aa", 1, 0) - MobHit("aa", 1, 400)) / 400;
            double ws = (MobHit("ws", 1, 0) - MobHit("ws", 1, 400)) / 400;
            Assert.True(System.Math.Abs(aa - ws) <= 0.005,
                Sources.Cite("KAN-III", $"damage per DEF: retail one slope for both, server auto-attack {aa:F3} / weaponskill {ws:F3}"));
        }
    }
}
