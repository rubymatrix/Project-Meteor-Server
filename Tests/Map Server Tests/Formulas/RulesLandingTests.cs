using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Status landing chance (formulas.statusLandChance and the sleep spells).
    [Collection("engines")]
    public sealed class RulesLandingTests
    {
        private readonly FormulaScript lua;

        public RulesLandingTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        [Theory]
        [InlineData(false)]
        [InlineData(true)]
        public void PureEnfeebleCap(bool useMacc)
        {
            double got = lua.One("enfeebleChance", 2000, useMacc);
            Assert.True(got <= 0.78,
                Sources.Cite("BG-107403", $"Pure enfeeble at very high {(useMacc ? "magic accuracy" : "potency")}: research at most 0.75 ±0.03, server {got}"));
        }

        [Theory]
        [InlineData("Command/Magic/Sleep")]
        [InlineData("Command/Magic/Repose")]
        public void SleepUsesMagicAccuracyOnly(string script)
        {
            double baseline = lua.One("sleepChance", script, 0.5, 0, 0);
            double morePotency = lua.One("sleepChance", script, 0.5, 200, 0);
            double lessMacc = lua.One("sleepChance", script, 0.5, 0, -50);
            Assert.True(morePotency == baseline,
                Sources.Cite("SEF-41900", $"{script} with +200 enfeebling potency: research unchanged, server {baseline} -> {morePotency}"));
            Assert.True(lessMacc < baseline,
                Sources.Cite("SEF-41900", $"{script} with -50 magic accuracy: research lower, server {baseline} -> {lessMacc}"));
        }
    }
}
