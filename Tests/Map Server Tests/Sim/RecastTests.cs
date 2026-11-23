using System.Linq;
using Xunit;

namespace Meteor.Map.Tests.Sim
{
    [Collection("sim")]
    [Rows("ACT-09", "PGL-16")]
    public class RecastTests
    {
        private const uint Featherfoot = 27103;
        private const ushort FirstSlot = 32;

        private static (SimWorld, Actors.Player) Pugilist()
        {
            var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            p.EquipAbility(2, Featherfoot, FirstSlot, false);
            return (w, p);
        }

        private static string Use(SimWorld w, Actors.Player p)
        {
            int before = w.Of("action.check", p).Count;
            p.Ability(Featherfoot, p.Id);
            w.Run(0.2);
            return w.Of("action.check", p).Skip(before).Select(e => (string)e["verdict"]).FirstOrDefault() ?? "none";
        }

        [Fact]
        public void UseStartsTheRecastAndTheGateHoldsUntilItEnds()
        {
            var (w, p) = Pugilist();
            using (w)
            {
                double recast = Server.GetWorldManager().GetBattleCommand(Featherfoot).maxRecastTimeSeconds;
                Assert.Equal(60, recast);

                w.Run(recast);
                Assert.Equal("ok", Use(w, p));
                Assert.Single(w.Of("status.apply", p));

                w.Run(10);
                Assert.Equal("recast", Use(w, p));
                Assert.Single(w.Of("status.apply", p));

                w.Run(recast - 10.4 - 1);
                Assert.Equal("recast", Use(w, p));

                w.Run(1);
                Assert.Equal("ok", Use(w, p));
                Assert.Equal(2, w.Of("status.apply", p).Count + w.Of("status.refresh", p).Count);
            }
        }

        [Fact]
        public void EquippingStartsTheRecast()
        {
            var (w, p) = Pugilist();
            using (w)
            {
                Assert.Equal("recast", Use(w, p));
                Assert.Empty(w.Of("status.apply", p));
            }
        }
    }
}
