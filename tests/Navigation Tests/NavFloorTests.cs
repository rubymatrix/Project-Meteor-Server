using System;
using System.Numerics;
using Xunit;
using S = Meteor.Navigation.Tests.Fixtures.SyntheticScene;

namespace Meteor.Navigation.Tests
{
    public class NavFloorTests
    {
        private static readonly Lazy<NavWorld> shared = new Lazy<NavWorld>(S.LoadWorld);
        private static NavInstance Fresh() => shared.Value.CreateInstance("test");

        // between the two floors, nearer the deck: where a drifting server Y puts a walker under it
        private static readonly Vector3 Between = new Vector3(225, 2.3f, 10);

        [Fact]
        public void NearestGroundBetweenFloorsIsTheDeck()
        {
            // the lookup the carried floor replaces: from between, the nearest ground is overhead
            var p = Fresh().Project(Between, NavAgent.Mob);
            Assert.True(p.Ok);
            Assert.InRange(p.Position.Y, 3.7f, 4.3f);
        }

        [Fact]
        public void LookupNeverPicksAFloorOverhead()
        {
            var floor = new NavFloor();
            var p = floor.Track(Fresh(), NavAgent.Mob, Between);
            Assert.True(p.Ok);
            Assert.InRange(p.Position.Y, -0.3f, 0.3f);
            Assert.Equal(1, floor.Acquired);
        }

        [Fact]
        public void CarriedFloorStaysUnderTheDeck()
        {
            var inst = Fresh();
            var floor = new NavFloor();
            Assert.True(floor.Track(inst, NavAgent.Mob, S.UnderDeck).Ok);
            for (int i = 1; i <= 20; i++)
            {
                // half a yalm a tick, its Y wandering up towards the deck
                var pos = new Vector3(S.UnderDeck.X + i * 0.5f, i % 2 == 0 ? 1.9f : 0.2f, S.UnderDeck.Z);
                var p = floor.Track(inst, NavAgent.Mob, pos);
                Assert.True(p.Ok);
                Assert.InRange(p.Position.Y, -0.3f, 0.3f);
                Assert.Equal(pos.X, p.Position.X, 2);
            }
            Assert.Equal(1, floor.Acquired);
        }

        [Fact]
        public void LiftedOrMovedFarLooksTheFloorUpAgain()
        {
            var inst = Fresh();
            var floor = new NavFloor();
            floor.Track(inst, NavAgent.Mob, S.UnderDeck);
            // straight up onto the deck: the walk keeps XZ, the floor 4 under it isn't the one it stands on
            var up = floor.Track(inst, NavAgent.Mob, S.OnDeck);
            Assert.InRange(up.Position.Y, 3.7f, 4.3f);
            Assert.Equal(2, floor.Acquired);
            // a warp across the map
            var far = floor.Track(inst, NavAgent.Mob, S.A);
            Assert.True(far.Ok);
            Assert.InRange(far.Position.Y, -0.3f, 0.3f);
            Assert.Equal(3, floor.Acquired);
        }

        [Fact]
        public void ResetLooksTheFloorUp()
        {
            var inst = Fresh();
            var floor = new NavFloor();
            floor.Track(inst, NavAgent.Mob, S.UnderDeck);
            floor.Reset();
            Assert.Equal(0, floor.Poly);
            floor.Track(inst, NavAgent.Mob, S.UnderDeck);
            Assert.Equal(2, floor.Acquired);
        }

        [Fact]
        public void RouteFromTheCarriedFloor()
        {
            var inst = Fresh();
            var floor = new NavFloor();
            floor.Track(inst, NavAgent.Mob, S.UnderDeck);
            var start = floor.Track(inst, NavAgent.Mob, Between);
            var to = new Vector3(235, 0, 10);
            // looked up from the position, the start is the deck, which doesn't reach the ground
            Assert.NotEqual(NavReason.Ok, inst.PlanRoute(Between, to, NavAgent.Mob).Reason);
            var route = inst.PlanRoute(start, Between, to, NavAgent.Mob);
            Assert.Equal(NavReason.Ok, route.Reason);
            Assert.All(route.Points, p => Assert.InRange(p.Y, -0.3f, 0.3f));
            Assert.True(route.Advance(start, Between) || route.Complete);
        }
    }
}
