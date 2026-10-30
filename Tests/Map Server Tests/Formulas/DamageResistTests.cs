using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Magic partial-resist rate (percent).
    [Collection("engines")]
    public sealed class DamageResistTests
    {
        private const int Thaumaturge = 22;
        private const int Conjurer = 23;

        private readonly FormulaScript lua;

        public DamageResistTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        // A Lv35 monster casting on a Lv50 conjurer with this much Magic Evasion.
        private double OnConjurer(double meva) => lua.One("resistRate", 0, 35, false, Conjurer, 50, true, meva, null);

        [Fact]
        public void PartySpellsOnIfrit()
        {
            double got = lua.One("resistRate", Thaumaturge, 50, true, 0, 58, false, null, null);
            Assert.True(got >= 9 && got <= 30, Sources.Cite("RCAP-IFRIT", $"Lv50 spells on Ifrit L58: retail 9-30% resisted, server {got:F1}%"));
        }

        // 0% to 100% over about 200 Magic Evasion.
        [Fact]
        public void RatePerMagicEvasion()
        {
            double perPoint = (OnConjurer(375) - OnConjurer(275)) / 100;
            Assert.True(perPoint >= 0.4 && perPoint <= 0.6,
                Sources.Cite("KAN-II", $"partial resist per Magic Evasion: retail 0.5 pts +-20%, server {perPoint:F3}"));
        }

        [Fact]
        public void NoCap()
        {
            double got = OnConjurer(5000);
            Assert.True(got >= 100, Sources.Cite("KAN-II", $"partial resist with very high Magic Evasion: retail reaches 100%, server {got:F1}%"));
        }

        [Fact]
        public void ElementalResistanceLeavesRateAlone()
        {
            double plain = lua.One("resistRate", Thaumaturge, 50, true, 0, 50, false, null, 0);
            double resistant = lua.One("resistRate", Thaumaturge, 50, true, 0, 50, false, null, 100);
            Assert.True(plain == resistant,
                Sources.Cite("KAN-II", $"Fire Resistance +100: retail resist rate unchanged, server {plain:F1}% -> {resistant:F1}%"));
        }
    }
}
