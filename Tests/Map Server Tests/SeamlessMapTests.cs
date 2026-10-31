using Meteor.Map.DataObjects;
using Xunit;

namespace Meteor.Map.Tests
{
    // Limsa Lominsa: sea0Town01 (133, the guild and inn half) and sea0Town01a (230, the aetheryte deck),
    // with their server_seamless_zonechange_bounds rows.
    public class SeamlessMapTests
    {
        private const uint Region = 101, Guilds = 133, Deck = 230;

        private static SeamlessMap Limsa()
        {
            var map = new SeamlessMap();
            map.AddRow(new SeamlessBoundry(Region, Guilds, Deck, -457, 131, -436, 142, -460, 92, -439, 100, -454, 101, -439, 128));
            map.AddRow(new SeamlessBoundry(Region, Guilds, Deck, -486, 228, -501, 218, -482, 255, -503, 242, -490, 238, -501, 229));
            map.AddRow(new SeamlessBoundry(Region, Guilds, Deck, -483, 200, -496, 181, -506, 206, -514, 177, -500, 198, -505, 185));
            map.SetTown(Guilds, true);
            map.SetTown(Deck, true);
            map.AddAnchor(Guilds, -460.2f, 40.0f, 179.7f); // Piralnaut
            map.AddAnchor(Guilds, -459.8f, 40.0f, 178.2f); // T'mokkri
            map.AddAnchor(Deck, -395.1f, 42.5f, 337.1f);   // aetheryte
            return map;
        }

        [Fact]
        public void StandingAtTheAetheryteStaysOnTheDeck()
        {
            var d = Limsa().Decide(Region, Deck, 0, -395, 337, -395, 42.5f, 337);
            Assert.Equal(SeamlessAction.None, d.action);
        }

        [Fact]
        public void WalkingUpToTheInnCountersMovesIntoTheGuildHalf()
        {
            var d = Limsa().Decide(Region, Deck, 0, -462, 182, -460, 40.0f, 180);
            Assert.Equal(SeamlessAction.ChangeZone, d.action);
            Assert.Equal(Guilds, d.zoneId);
        }

        [Fact]
        public void TheMergeBoxMergesTheOtherHalf()
        {
            var d = Limsa().Decide(Region, Deck, 0, -446, 98, -446, 40.0f, 110);
            Assert.Equal(SeamlessAction.Merge, d.action);
            Assert.Equal(Guilds, d.zoneId);
        }

        [Fact]
        public void ReachingTheOtherBoxAfterTheMergeChangesZone()
        {
            var d = Limsa().Decide(Region, Deck, Guilds, -446, 125, -446, 40.0f, 136);
            Assert.Equal(SeamlessAction.ChangeZone, d.action);
            Assert.Equal(Guilds, d.zoneId);
        }

        [Fact]
        public void FarFromTheSeamTheMergeIsDropped()
        {
            var d = Limsa().Decide(Region, Deck, Guilds, -395, 337, -395, 42.5f, 337);
            Assert.Equal(SeamlessAction.ClearMerge, d.action);
        }

        [Fact]
        public void SegmentThroughANarrowBoxCounts()
        {
            Assert.True(SeamlessBoundaryPolicy.SegmentIntersects(0, -10, 0, 10, -1, -1, 1, 1));
            Assert.False(SeamlessBoundaryPolicy.SegmentIntersects(5, -10, 5, 10, -1, -1, 1, 1));
        }

        private sealed class A { }

        [Fact]
        public void CrossingKeepsTheOldZoneListingThePlayer()
        {
            A deck = new A(), guilds = new A(), other = new A();
            var plan = SeamCrossing<A>.Plan(deck, guilds, guilds, deck);
            Assert.False(plan.removeFromOld);
            Assert.Null(plan.dropMerged);
            Assert.Null(plan.addMerged);
            Assert.Same(deck, plan.merged);

            plan = SeamCrossing<A>.Plan(deck, other, guilds, deck);
            Assert.Same(other, plan.dropMerged);
        }
    }
}
