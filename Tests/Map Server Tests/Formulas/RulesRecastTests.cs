using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Recasts the ability scripts change from the command row.
    [Collection("engines")]
    public sealed class RulesRecastTests
    {
        private readonly FormulaScript lua;

        public RulesRecastTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        // Script, row recast (s), trait, item and its slot, research recast (s).
        [Theory]
        [InlineData("Command/Ability/BloodForBlood", 60, 27284, 0, 0, 45, "RCAP-IFRIT")]
        [InlineData("Command/Ability/Jump", 60, 0, 8051404, 12, 54, "RCAP-IFRIT")]
        [InlineData("Command/Ability/Taunt", 60, 27122, 0, 0, 45, "CL-CMD")]
        public void RecastWithTraitOrGear(string script, int rowSeconds, int trait, int item, int slot, int want, string source)
        {
            double got = lua.One("abilityRecast", script, rowSeconds * 1000, trait, item, slot) / 1000;
            Assert.True(System.Math.Abs(got - want) <= 1, Sources.Cite(source, $"{script} recast: research {want} ±1 s, server {got} s"));
        }

        [Theory]
        [InlineData("Command/Ability/Chameleon", 180, 27245, 60)]
        [InlineData("Command/Ability/SacredPrism", 90, 27360, 30)]
        public void SwiftTraitCut(string script, int rowSeconds, int trait, int cut)
        {
            double got = rowSeconds - lua.One("abilityRecast", script, rowSeconds * 1000, trait, 0, 0) / 1000;
            Assert.True(System.Math.Abs(got - cut) <= 1, Sources.Cite("CL-CMD", $"{script} recast cut by its Swift trait: research {cut} ±1 s, server {got} s"));
        }

        [Fact]
        public void LightShotRecastIsBowDelay()
        {
            double got = lua.One("lightShotRecast", 3.5) / 1000;
            Assert.True(got == 3.5, Sources.Cite("PN118", $"Light Shot recast with a 3.5 s bow: research 3.5 s, server {got} s"));
        }
    }
}
