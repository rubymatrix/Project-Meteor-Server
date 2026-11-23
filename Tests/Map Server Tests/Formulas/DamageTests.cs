using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // One auto-attack between level-typical characters, without the random spread, against the
    // normal (not critical, blocked or parried) hits retail sent in the same fight.
    [Covers("formulas.physicalDamage", "formulas.physicalStatRatio", "formulas.statCaps", "formulas.defenseReduction", "formulas.effectiveDefense", "stats.weapon", "stats.mobExpected")]
    [Collection("engines")]
    public sealed class DamageTests
    {
        private const string Source = "CAP-AA";

        private const int Gladiator = 3;
        private const int Marauder = 4;

        private readonly FormulaScript lua;

        public DamageTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // Attacker class, level, weapon Damage and delay; monster level; the retail band.
        [Theory]
        [InlineData(Marauder, 26, 46, 4.2, 30, 44, 51)]
        [InlineData(Gladiator, 27, 26, 2.5, 30, 18, 22)]
        public void PlayerHitsMonster(int classId, int level, int damage, double delay, int mobLevel, int low, int high)
        {
            int got = (int)lua.One("autoAttackDamage", classId, level, damage, delay, 0, mobLevel, false);
            Assert.True(got >= low && got <= high,
                Sources.Cite(Source, $"Lv{level} class {classId} on Lv{mobLevel}: retail {low}-{high}, server {got}"));
        }

        [Fact]
        public void MonsterHitsPlayer()
        {
            int got = (int)lua.One("autoAttackDamage", 0, 30, null, null, Gladiator, 27, true);
            Assert.True(got >= 56 && got <= 63,
                Sources.Cite(Source, $"Lv30 piranha on Lv27 gladiator: retail 56-63, server {got}"));
        }
    }
}
