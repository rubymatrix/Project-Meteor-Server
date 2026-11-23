using System;
using Meteor.Map.actors.chara.ai.utils;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    public sealed class TpTests
    {
        private const string Source = "CAP-TP";

        [Theory]
        [InlineData(3.1, 50, 326)] // Lv50 Dragoon, 3.1 s lance, +5% Store TP trait
        [InlineData(4.0, 0, 400)]  // Lv50 Warrior, 4.0 s axe
        public void PlayerSwing(double delay, int storeTp, int expected)
        {
            int got = TpGain.PlayerSwing(delay, storeTp);
            Assert.True(got == expected, Sources.Cite(Source, $"{delay} s, Store TP {storeTp}: expected {expected}, got {got}"));
        }

        [Fact]
        public void MonsterSwing()
        {
            Assert.True(TpGain.MonsterSwing == 300, Sources.Cite(Source, "monster swing"));
        }

        [Theory]
        [InlineData(1)]
        [InlineData(2)]
        [InlineData(3)]
        public void SwingSplitsAcrossTheWeaponsHits(int baseHits)
        {
            int swing = 287, sum = 0;
            for (int hit = 1; hit <= baseHits; hit++)
                sum += TpGain.ForHit(swing, hit, baseHits);
            Assert.True(sum == swing, Sources.Cite(Source, $"{baseHits} hits: {sum} of {swing}"));
            Assert.True(TpGain.ForHit(swing, baseHits + 1, baseHits) == 144, Sources.Cite(Source, "extra hit is half a swing"));
        }

        // The fit against the per-level rates read from captures.
        [Theory]
        [InlineData(26, 0.82, 0.84)]
        [InlineData(27, 0.77, 0.79)]
        [InlineData(50, 0.17, 0.18)]
        public void PlayerTakenRate(int level, double low, double high)
        {
            double k = TpGain.DamageTakenRate(false, level, 0);
            Assert.True(k >= low - 0.005 && k <= high + 0.005, Sources.Cite(Source, $"Lv{level}: {k:F4}, seen {low}-{high}"));
        }

        // Monster rate 1600 / max HP, within 10% of what was seen.
        [Theory]
        [InlineData(550, 3.135, 3.135)]
        [InlineData(770, 1.71, 1.91)]
        [InlineData(679, 2.49, 2.49)]
        [InlineData(437, 3.71, 3.71)]
        [InlineData(32000, 0.048, 0.053)]
        public void MonsterTakenRate(int maxHp, double low, double high)
        {
            double k = TpGain.DamageTakenRate(true, 30, maxHp);
            Assert.True(k >= low * 0.9 && k <= high * 1.1, Sources.Cite(Source, $"{maxHp} HP: {k:F4}, seen {low}-{high}"));
        }

        [Fact]
        public void TakenRoundsUp()
        {
            Assert.True(TpGain.FromDamageTaken(false, 50, 0, 1) == 1, Sources.Cite(Source, "1 damage gives 1 TP"));
            Assert.True(TpGain.FromDamageTaken(false, 50, 0, 0) == 0, Sources.Cite(Source, "no damage, no TP"));
        }
    }
}
