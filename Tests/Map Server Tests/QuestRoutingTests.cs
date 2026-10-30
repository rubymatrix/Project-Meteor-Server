using System.Collections.Generic;
using System.Linq;
using Meteor.Map.Actors.QuestNS;
using Xunit;

namespace Meteor.Map.Tests
{
    public class QuestRoutingTests
    {
        [Fact]
        public void RoutingPrefersTheGateOwnerThenTheNamedOwnerThenTheEnabledEvent()
        {
            // name, owns by gate, owns by name, event enabled
            var quests = new List<(string name, bool gate, bool named, bool kind)>
            {
                ("Lnc300", false, false, true),
                ("Gla306", false, true, true),
                ("Min306", true, false, false),
                ("Fsh300", false, false, false),
            };
            var ordered = QuestNpcRouting.Order(quests, q => QuestNpcRouting.Score(q.gate, q.named, q.kind));
            Assert.Equal(new[] { "Min306", "Gla306", "Lnc300", "Fsh300" }, ordered.Select(q => q.name));
        }

        [Fact]
        public void RoutingKeepsTheIncomingOrderOnATie()
        {
            var quests = new List<string> { "B", "A", "C" };
            Assert.Equal(quests, QuestNpcRouting.Order(quests, q => 0));
        }

        [Theory]
        [InlineData("Gla306", "gla306_stands_trig", true)]
        [InlineData("Gla306", "GLA306_bazaar_trig", true)]
        [InlineData("Gla306", "gla3060_x", false)]
        [InlineData("Gla300", "gla306_stands_trig", false)]
        [InlineData("Man0u1", "", false)]
        public void SpawnNamePrefixNamesTheOwner(string quest, string uniqueId, bool owns)
        {
            Assert.Equal(owns, QuestNpcRouting.OwnsByName(quest, uniqueId));
        }

        [Fact]
        public void GateSequenceRange()
        {
            var always = new QuestGate(110462);
            Assert.True(always.Admits(0));
            Assert.True(always.Admits(65535));
            var stop = new QuestGate(110462, 13, 13);
            Assert.False(stop.Admits(10));
            Assert.True(stop.Admits(13));
            Assert.False(stop.Admits(15));
        }
    }
}
