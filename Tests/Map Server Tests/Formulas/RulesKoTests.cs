using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // KO penalties and Raise, through Battle/Ko.lua and the Weakness, Brink of Death and Raise scripts.
    [Collection("engines")]
    public sealed class RulesKoTests
    {
        private const int Weakness = 223165;
        private const int Brink = 223197;

        private readonly FormulaScript lua;

        public RulesKoTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        [Theory]
        [InlineData(2774, 1914)]
        [InlineData(2206, 3279)]
        public void WeaknessCutsMaxHpAndMp(int hp, int mp)
        {
            var r = lua.Call("weakness", hp, mp);
            Assert.True(System.Math.Abs(r[0] - hp * 0.75) <= 1, Sources.Cite("CL-STATUS", $"Weakness max HP from {hp}: research {hp * 0.75} ±1, server {r[0]}"));
            Assert.True(System.Math.Abs(r[1] - mp * 0.75) <= 1, Sources.Cite("CL-STATUS", $"Weakness max MP from {mp}: research {mp * 0.75} ±1, server {r[1]}"));
            Assert.True(r[2] == 180, Sources.Cite("CL-STATUS", $"Weakness duration: research 180 s, server {r[2]}"));
        }

        [Fact]
        public void BrinkOfDeathHalvesPoolsAndBattleStats()
        {
            var r = lua.Call("brinkShares");
            string[] names = { "max HP", "max MP", "attack", "magic potency", "defense", "magic defense (elemental resistance)" };
            for (int i = 0; i < names.Length; i++)
                Assert.True(System.Math.Abs(r[i] - 0.5) < 1e-9,
                    Sources.Cite(i < 2 ? "CL-STATUS" : "PN118", $"Brink of Death {names[i]}: research x0.5, server x{r[i]}"));
        }

        [Fact]
        public void WeakPlayerRaisedGetsBrinkOfDeath()
        {
            var r = lua.Call("revivePenalty", Weakness, "raise", true);
            Assert.True(r[0] == Brink, Sources.Cite("PN118", $"Raised while Weak: research Brink of Death {Brink}, server {r[0]}"));
            Assert.True(r[2] == 1, Sources.Cite("2N-942", $"Raised while Weak: research one penalty status, server {r[2]} added"));
            Assert.True(r[1] <= 180, Sources.Cite("2N-942", $"Brink duration after Weakness: research at most 180 s, server {r[1]}"));
        }

        [Fact]
        public void BrinkDoesNotEscalateFurther()
        {
            var r = lua.Call("revivePenalty", Brink, "raise", true);
            Assert.True(r[0] == Brink, Sources.Cite("2N-942", $"Raised while in Brink: research Brink again, server {r[0]}"));
            Assert.True(r[2] == 1 && r[1] <= 180, Sources.Cite("2N-942", $"Raised while in Brink: research one status, at most 180 s; server {r[2]} added, {r[1]} s"));
        }

        [Fact]
        public void EnhancedRaiseRestoresFullHpWithoutPenalty()
        {
            var r = lua.Call("raiseOffer", true);
            Assert.True(r[0] == 100, Sources.Cite("RCAP-IFRIT", $"Enhanced Raise HP: research 100%, server {r[0]}%"));
            Assert.True(r[1] == 0, Sources.Cite("RCAP-IFRIT", "Enhanced Raise: research no Weakness, server offers the KO penalty"));
            Assert.True(lua.One("revivePenalty", 0, "raise", false) == 0,
                Sources.Cite("RCAP-IFRIT", "Revive with the penalty blocked: research no status, server applied one"));
        }

        [Fact]
        public void RaiseWithoutEnhancedRaiseGivesWeakness()
        {
            Assert.True(lua.Call("raiseOffer", false)[1] == 1,
                Sources.Cite("PN118", "Raise without Enhanced Raise: research Weakness, server offers no penalty"));
            double id = lua.One("revivePenalty", 0, "raise", true);
            Assert.True(id == Weakness, Sources.Cite("PN118", $"First raise: research Weakness {Weakness}, server {id}"));
        }

        [Fact]
        public void ReturnGivesWeaknessWithTheSameEscalation()
        {
            double first = lua.One("revivePenalty", 0, "return", true);
            double again = lua.One("revivePenalty", Weakness, "return", true);
            Assert.True(first == Weakness, Sources.Cite("PN118", $"Return while KO'd: research Weakness, server {first}"));
            Assert.True(again == Brink, Sources.Cite("PN118", $"Return while Weak: research Brink of Death, server {again}"));
        }

        [Fact]
        public void RaiseMpCostAtLevel50()
        {
            double got = lua.One("mpCost", 50, 150);
            Assert.True(got == 420, Sources.Cite("CL-CMD", $"Raise MP at Lv50 (150 per mille): research 420, server {got}"));
        }

        [Fact]
        public void RaiseCorpseEntryText()
        {
            double text = lua.Call("raiseOffer", false)[2];
            Assert.True(text == 30354, Sources.Cite("RCAP-IFRIT", $"Raise corpse entry text: research 30354, server {text}"));
        }
    }
}
