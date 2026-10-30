using Meteor.Map.Actors;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.group;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // PlayerPartyBonus: which bonus a party size gives and who counts toward it.
    [Collection("engines")]
    public sealed class EnginePartyBonusTests : EngineHarness
    {
        public EnginePartyBonusTests(EngineFixture engines) { }

        private Player PartyOf(short myLevel, params short[] memberLevels)
        {
            var me = PlayerShell(0xA2000001, myLevel);
            var party = new Party(1, me.Id);
            foreach (var level in memberLevels)
                party.members.Add(Pc(level).Id);
            me.currentParty = party;
            return me;
        }

        [Fact]
        public void PartySizePicksTheBonus()
        {
            (int size, uint bonus, string name)[] cases =
            {
                (3, 0, "none"),
                (4, (uint)StatusEffectId.Comradery, "Comradery"),
                (7, (uint)StatusEffectId.Comradery, "Comradery"),
                (8, (uint)StatusEffectId.StrengthinNumbers, "Strength in Numbers"),
            };
            foreach (var (size, bonus, name) in cases)
            {
                var others = new short[size - 1];
                for (int i = 0; i < others.Length; i++)
                    others[i] = 50;
                var me = PartyOf(50, others);
                Assert.True(me.GetWantedPartyBonus() == bonus, Sources.Cite("PN117", $"party of {size}: {name}, got {me.GetWantedPartyBonus()}"));
            }
        }

        [Fact]
        public void MembersCountWithin5LevelsAboveAnd10Below()
        {
            var me = PartyOf(50, 55, 40, 56, 39);
            int counted = me.CountPartyBonusMembers((Party)me.currentParty);
            Assert.True(counted == 3, Sources.Cite("2N-800", $"Lv50 with Lv55, 40, 56, 39: self, 55 and 40 count = 3, got {counted}"));
        }
    }
}
