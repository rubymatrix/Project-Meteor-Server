using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // MP costs: ceil(base(level) x permille / 1000), as the client's calculateCommandCost.
    [Collection("engines")]
    public sealed class DamageCostTests
    {
        private readonly FormulaScript lua;

        public DamageCostTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_damage");
        }

        [Theory]
        [InlineData(1, 110)]
        [InlineData(10, 200)]
        [InlineData(20, 400)]
        [InlineData(30, 800)]
        [InlineData(40, 1500)]
        [InlineData(50, 2800)]
        public void CostBase(int level, int expected)
        {
            int got = (int)lua.One("commandCostBase", level);
            Assert.True(got == expected, Sources.Cite("CL-COST", $"cost base at Lv{level}: client {expected}, server {got}"));
        }

        // Lv50 hotbar costs seen in retail footage.
        [Theory]
        [InlineData("Thunder", 75, 210)]
        [InlineData("Thundara", 135, 378)]
        [InlineData("Thundaga", 195, 546)]
        [InlineData("Burst", 90, 252)]
        [InlineData("Freeze", 120, 336)]
        [InlineData("Flare", 200, 560)]
        [InlineData("Firaga", 255, 714)]
        [InlineData("Sleepga", 100, 280)]
        public void Lv50BlackMageCosts(string spell, int permille, int expected)
        {
            int got = (int)lua.One("mpCost", 50, permille);
            Assert.True(got == expected, Sources.Cite("VID-Q0HO", $"Lv50 {spell}: retail {expected} MP, server {got}"));
        }

        [Theory]
        [InlineData("Cure", 40, 112)]
        [InlineData("Cura", 100, 280)]
        [InlineData("Curaga", 150, 420)]
        [InlineData("Raise", 150, 420)]
        [InlineData("Esuna", 40, 112)]
        [InlineData("Regen", 20, 56)]
        [InlineData("Repose", 80, 224)]
        [InlineData("Protect", 80, 224)]
        public void Lv50ConjurerCosts(string spell, int permille, int expected)
        {
            int got = (int)lua.One("mpCost", 50, permille);
            Assert.True(got == expected, Sources.Cite("CL-COST", $"Lv50 {spell}: client {expected} MP, server {got}"));
        }

        [Theory]
        [InlineData("Cure", 1, 40, 5)]
        [InlineData("Thunder", 1, 75, 9)]
        [InlineData("Thunder", 10, 75, 15)]
        [InlineData("Thunder", 20, 75, 30)]
        [InlineData("Thunder", 30, 75, 60)]
        [InlineData("Thunder", 40, 75, 113)]
        public void LowLevelCosts(string spell, int level, int permille, int expected)
        {
            int got = (int)lua.One("mpCost", level, permille);
            Assert.True(got == expected, Sources.Cite("CL-COST", $"Lv{level} {spell}: client {expected} MP, server {got}"));
        }

        [Theory]
        [InlineData("Holy Succor", 100, 280)]
        [InlineData("Decoy", 100, 280)]
        [InlineData("Swiftsong", 100, 280)]
        [InlineData("Paeon of War", 50, 140)]
        [InlineData("Sanguine Rite", 120, 336)]
        public void Lv50AbilityCosts(string action, int permille, int expected)
        {
            int got = (int)lua.One("mpCost", 50, permille);
            Assert.True(got == expected, Sources.Cite("W2N", $"Lv50 {action}: retail {expected} MP, server {got}"));
        }
    }
}
