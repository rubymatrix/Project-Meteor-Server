using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Regen's HP per tick as Command/Magic/Regen.lua sizes it from Enhancing Magic Potency.
    [Collection("engines")]
    public sealed class RulesRegenTests
    {
        private readonly FormulaScript lua;

        public RulesRegenTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        [Fact]
        public void CapAtLevel50()
        {
            double got = lua.One("regenTick", 438, false);
            Assert.True(got >= 203 * 0.9 && got <= 203 * 1.1,
                Sources.Cite("SEF-40800", $"Regen per tick at 438 Enhancing potency: research 203 ±10%, server {got}"));
        }

        [Fact]
        public void PerTickShareOfPotency()
        {
            const int potency = 250;
            double got = lua.One("regenTick", potency, false);
            double low = 0.625 * potency * 0.9, high = 0.75 * potency * 1.1;
            Assert.True(got >= low && got <= high,
                Sources.Cite("SEF-40800", $"Regen per tick at {potency} Enhancing potency: research 0.625-0.75 x potency ({low:F0}-{high:F0}), server {got}"));
        }

        [Fact]
        public void HealersBootsAddAQuarter()
        {
            double plain = lua.One("regenTick", 250, false);
            double af = lua.One("regenTick", 250, true);
            Assert.True(af / plain >= 1.25 * 0.9 && af / plain <= 1.25 * 1.1,
                Sources.Cite("SEF-40800", $"Regen with the AF boots vs without: research x1.25 ±10%, server {plain} -> {af}"));
        }
    }
}
