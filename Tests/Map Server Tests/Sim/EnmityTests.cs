using System.Linq;
using Meteor.Map.Actors;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    [Collection("sim")]
    [Rows("CMB-04")]
    public class EnmitySwitchTests
    {
        [Fact]
        public void MobTurnsToWhoeverHoldsTheMostEnmity()
        {
            using var w = SimWorld.Create(seed: 5);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10, x: 0, z: 2);
            var a = w.AddPlayer(2, 10, x: 0, z: 0);
            var b = w.AddPlayer(2, 16, x: 1.5f, z: 1);
            SimWorld.Durable(m);
            SimWorld.Durable(a);
            SimWorld.Durable(b);
            SimWorld.Party(a, b);

            w.Attack(a, m);
            w.Run(6);
            w.Attack(b, m);
            w.Run(90);

            var turns = w.Of("ai.target", m).Where(e => e.Target != 0).ToList();
            Assert.Equal(a.Id, turns.First().Target);
            Assert.Contains(turns, e => e.Target == b.Id);

            // At every turn, the new target holds the most enmity.
            foreach (var turn in turns)
            {
                var latest = w.Of("enmity.change", m).Where(e => e.Seq < turn.Seq)
                    .GroupBy(e => e.Target).ToDictionary(g => g.Key, g => g.Last().Number("cumulative"));
                Assert.Equal(latest.OrderByDescending(kv => kv.Value).First().Key, turn.Target);
            }

            // The mob's swings go to its target of the moment.
            foreach (var swing in w.Of("action.result", m))
            {
                var current = turns.Last(e => e.Seq < swing.Seq);
                Assert.Equal(current.Target, swing.Target);
            }
        }

        [Fact]
        [Rows("CMB-03")]
        public void AnotherPartyCannotHitAClaimedMob()
        {
            using var w = SimWorld.Create(seed: 5);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10, x: 0, z: 2);
            var a = w.AddPlayer(2, 10, x: 0, z: 0);
            var b = w.AddPlayer(2, 10, x: 1.5f, z: 1);
            SimWorld.Durable(m);
            SimWorld.Durable(a);

            w.Attack(a, m);
            w.Run(1);
            w.Attack(b, m);
            w.Run(10);

            Assert.Empty(w.Of("action.result", b));
            Assert.All(w.Of("action.check", b), e => Assert.Equal("target", (string)e["verdict"]));
            Assert.NotEmpty(w.Of("action.check", b));
        }
    }
}
