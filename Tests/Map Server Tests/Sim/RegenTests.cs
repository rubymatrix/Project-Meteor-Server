using System;
using System.Linq;
using Meteor.Map.actors.chara;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    [Collection("sim")]
    [Rows("CMB-09")]
    public class RegenTests
    {
        private const uint RegenStatus = 223180;

        [Fact]
        public void RegenHealsItsMagnitudeEveryThreeSeconds()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(6, 30);
            p.SetHP(100);
            w.Run(0.1);

            p.statusEffects.AddStatusEffect(RegenStatus, 1, 10, 30, 0);
            w.Run(15);

            var ticks = w.Of("regen.tick", p);
            Assert.True(ticks.Count >= 4, $"{ticks.Count} ticks");
            for (int i = 1; i < ticks.Count; i++)
                Assert.Equal(3.0, w.Seconds(ticks[i]) - w.Seconds(ticks[i - 1]), 3);
            foreach (var t in ticks)
            {
                Assert.Equal(10, t.Number("regen"));
                var heal = w.Events.Events.Single(e => e.Kind == "hp.change" && e.Cause == t.Seq);
                Assert.Equal(10, heal.Number("delta"));
            }
        }

        [Fact]
        public void RegenStopsAtMaxHp()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(6, 30);
            p.SetHP((uint)(p.GetMaxHP() - 15));
            p.statusEffects.AddStatusEffect(RegenStatus, 1, 10, 30, 0);
            w.Run(12);

            Assert.Equal(p.GetMaxHP(), p.GetHP());
            Assert.All(w.Of("hp.change", p), e => Assert.True(e.Number("value") <= e.Number("max")));
        }

        [Fact]
        public void RegenEndsWithItsStatus()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(6, 30);
            p.SetHP(100);
            p.statusEffects.AddStatusEffect(RegenStatus, 1, 10, 9, 0);
            w.Run(20);

            double expired = w.Seconds(w.Of("status.expire", p).Single(e => e.Number("id") == RegenStatus));
            Assert.DoesNotContain(w.Of("regen.tick", p), e => w.Seconds(e) > expired);
            Assert.Equal(0, p.GetMod(Modifier.Regen));
        }

        // A 61 s gap counts as 61 s, not as its seconds part (1 s).
        [Fact]
        public void RegenTicksAfterALongPause()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(6, 30);
            p.SetHP(100);
            p.statusEffects.AddStatusEffect(RegenStatus, 1, 10, 600, 0);
            w.Run(3.1);
            int before = w.Of("regen.tick", p).Count;

            w.Clock.Advance(61);
            w.Run(0.1);

            Assert.Equal(before + 1, w.Of("regen.tick", p).Count);
        }
    }
}
