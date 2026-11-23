using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    [Covers("stats.mobHp", "stats.mobFamilyHpMult", "stats.interpGeo")]
    [Collection("engines")]
    public sealed class MonsterHpTests
    {
        private const string Source = "CAP-MOBHP";

        private readonly FormulaScript lua;

        public MonsterHpTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // Level, server_battlenpc_genus id (0 for a family at 1.0), max HP seen, capture and frame.
        [Theory]
        [InlineData(1, 0, 67, "gridania_to_coerthas f474 lesser petitghost")]
        [InlineData(1, 0, 67, "attack_rat f25 bug")]
        [InlineData(5, 0, 102, "gridania_to_coerthas f356 chigoe")]
        [InlineData(10, 0, 175, "gridania_to_coerthas f898 monkey")]
        [InlineData(16, 1002, 269, "gridania_to_coerthas f1099 firefly")]
        [InlineData(16, 14, 380, "teleport_to_camp_tranquil f62 funguar")]
        [InlineData(26, 0, 603, "combat_autoattack f123 slug")]
        [InlineData(26, 0, 603, "login f23 jellyfish")]
        [InlineData(32, 0, 897, "party_battle_leve f3458 crab")]
        [InlineData(41, 0, 1621, "whole_login f26 petitghost")]
        [InlineData(41, 12, 1946, "teleport_to_camp_nine_ivies f86 glirulus")]
        [InlineData(47, 0, 2356, "whole_login f25 gigantoad")]
        [InlineData(67, 26, 8373, "teleport_to_camp_nine_ivies f87 goblin")]
        [InlineData(76, 0, 10693, "war_quest_update2 f642 bomb")]
        [InlineData(78, 0, 11703, "war_quest_update2 f641 bomb, f643 cactus")]
        [InlineData(88, 23, 21501, "war_quest_update2 f645 Amalj'aa pugilist")]
        public void MatchesCapture(int level, int genusId, int seen, string where)
        {
            int got = (int)lua.One("mobHp", level, genusId);
            Assert.True(seen == got, Sources.Cite(Source, $"Lv{level} {where}: retail {seen}, server {got}"));
        }
    }
}
