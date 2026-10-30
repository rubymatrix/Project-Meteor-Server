using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Scripted consumables in Battle/Items.lua.
    [Collection("engines")]
    public sealed class RulesConsumableTests
    {
        private const int BlindingPotion = 3020301;
        private const int PoisoningPotion = 3020306;
        private const int Protect = 223129, Shell = 223130;

        private readonly FormulaScript lua;

        public RulesConsumableTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines, "combat_rules");
        }

        [Fact]
        public void EnfeeblingPotionIgnoresUserStats()
        {
            double weak = lua.One("potionLandings", BlindingPotion, 1, 400);
            double strong = lua.One("potionLandings", BlindingPotion, 1000, 400);
            Assert.True(weak == strong,
                Sources.Cite("PN121-I", $"Blinding Potion landings in 400 throws: research the same for any user, server {weak} (low stats) vs {strong} (high stats)"));
        }

        [Theory]
        [InlineData(3020301, 10)]
        [InlineData(3020302, 10)]
        [InlineData(3020303, 10)]
        [InlineData(3020304, 10)]
        [InlineData(PoisoningPotion, 20)]
        [InlineData(3020307, 10)]
        [InlineData(3020308, 10)]
        public void EnfeeblingPotionDuration(int itemId, int seconds)
        {
            var r = lua.Call("enfeeblePotion", itemId);
            Assert.True(r[0] > 0, Sources.Cite("EL-MED", $"Item {itemId}: research an enfeebling potion, server has no entry"));
            for (int i = 0; i < r[0]; i++)
                Assert.True(r[2 + 2 * i] == seconds, Sources.Cite("EL-MED", $"Item {itemId} status {r[1 + 2 * i]}: research {seconds} s, server {r[2 + 2 * i]} s"));
        }

        [Theory]
        [InlineData(3020501, Protect)]
        [InlineData(3020502, Shell)]
        public void UnguentGivesFiveMinutes(int itemId, int statusId)
        {
            var r = lua.Call("unguent", itemId);
            Assert.True(r[0] == statusId, Sources.Cite("EL-MED", $"Item {itemId}: research status {statusId}, server {r[0]}"));
            Assert.True(r[1] == 300, Sources.Cite("EL-MED", $"Item {itemId} duration: research 300 s, server {r[1]}"));
        }

        [Fact]
        public void MaddeningPotionEnmity()
        {
            var r = lua.Call("maddening", 50);
            foreach (var got in r)
                Assert.True(System.Math.Abs(got - 190) <= 10,
                    Sources.Cite("T-36468", $"Maddening Potion at Lv50 per enemy: research 190 ±10, server {got}"));
        }
    }
}
