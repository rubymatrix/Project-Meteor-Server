using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Comradery and Strength in Numbers through their status scripts (Battle/Partybonus.lua).
    [Collection("engines")]
    public sealed class RulesPartyBonusTests
    {
        private readonly FormulaScript lua;

        public RulesPartyBonusTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        private static void Share(double got, double want, string id, string what) =>
            Assert.True(System.Math.Abs(got - want) < 1e-9, Sources.Cite(id, $"{what}: research +{want:P0}, server +{got:P1}"));

        [Theory]
        [InlineData("Status/Comradery", 0.05)]
        [InlineData("Status/StrengthInNumbers", 0.10)]
        public void MaxHpAndMp(string script, double want)
        {
            var r = lua.Call("partyBonus", script);
            Share(r[0], want, "PN117", $"{script} max HP");
            Share(r[1], want, "PN117", $"{script} max MP");
        }

        [Theory]
        [InlineData("Status/Comradery", 0.10)]
        [InlineData("Status/StrengthInNumbers", 0.20)]
        public void PhysicalAccuracy(string script, double want)
        {
            Share(lua.Call("partyBonus", script)[2], want, "PN121-B", $"{script} physical accuracy");
        }

        [Theory]
        [InlineData("Status/Comradery", 0.05)]
        [InlineData("Status/StrengthInNumbers", 0.10)]
        public void MagicAccuracy(string script, double want)
        {
            Share(lua.Call("partyBonus", script)[3], want, "PN117", $"{script} magic accuracy");
        }
    }
}
