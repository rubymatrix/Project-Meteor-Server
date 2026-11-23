using System.Linq;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    [Collection("sim")]
    [Rows("CMB-02", "CMB-07")]
    public class AutoAttackTests
    {
        [Fact]
        public void EachSideSwingsOncePerItsOwnDelay()
        {
            using var w = SimWorld.Create(seed: 7);
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(p);
            SimWorld.Durable(m);

            w.Attack(p, m);
            w.Run(60);

            foreach (var (who, other) in new[] { (p as Actors.Character, m as Actors.Character), (m, p) })
            {
                var swings = w.Of("action.result", who).Where(e => e.Target == other.Id).Select(w.Seconds).ToList();
                Assert.True(swings.Count >= 10, $"{who.Id}: {swings.Count} swings");
                double delay = who.GetAttackDelayMs() / 1000.0;
                for (int i = 1; i < swings.Count; i++)
                    Assert.Equal(delay, swings[i] - swings[i - 1], 3);
            }
        }

        [Fact]
        public void FirstSwingLandsOnTheTickAfterEngaging()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(m);

            w.Attack(p, m);
            w.Run(1);

            Assert.Equal(0.1, w.Seconds(w.Of("action.result", p).First()), 3);
        }

        [Fact]
        public void MissesKeepTheCadenceAndDealNothing()
        {
            using var w = SimWorld.Create(seed: 3);
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(p);
            SimWorld.Durable(m);

            w.Attack(p, m);
            w.Run(600);

            var results = w.Of("action.result").ToList();
            var misses = results.Where(e => (string)e["hitType"] == "Miss").ToList();
            Assert.NotEmpty(misses);
            foreach (var e in misses)
            {
                Assert.Equal(0, e.Number("amount"));
                Assert.Equal(e.Number("hpBefore"), e.Number("hpAfter"));
            }
            // Every result rolled hit/miss once, and the outcome matches the roll.
            foreach (var e in results)
            {
                var hit = w.Events.Events.Single(r => r.Kind == "roll" && r.Cause == e.Seq && (string)r["name"] == "hit");
                Assert.Equal((string)e["hitType"] != "Miss", (bool)hit["outcome"]);
            }
        }

        [Fact]
        public void SameSeedReplaysTheSameFight()
        {
            string Fight(ulong seed)
            {
                using var w = SimWorld.Create(seed);
                var p = w.AddPlayer(2, 10);
                var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
                w.Attack(p, m);
                w.Run(30);
                return string.Join(";", w.Of("action.result").Select(e => $"{w.Seconds(e):F1}:{e.Actor == p.Id}:{e["hitType"]}:{e["amount"]}"));
            }

            Assert.Equal(Fight(11), Fight(11));
            Assert.NotEqual(Fight(11), Fight(12));
        }
    }
}
