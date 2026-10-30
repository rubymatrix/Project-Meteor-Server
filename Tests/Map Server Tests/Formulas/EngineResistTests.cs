using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.packets.send.actor.battle;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Hit outcomes in BattleUtils and CommandResult: resist tiers, what breaks a combo, block and parry.
    [Collection("engines")]
    public sealed class EngineResistTests : EngineHarness
    {
        public EngineResistTests(EngineFixture engines) { }

        private static CommandResult Result(ushort amount, HitType hit) =>
            new CommandResult(0, 0, 0, amount) { hitType = hit };

        [Fact]
        public void ResistTiersTakeAQuarterAHalfAndThreeQuarters()
        {
            var expected = new[] { (HitType.SingleResist, 750), (HitType.DoubleResist, 500), (HitType.TripleResist, 250) };
            foreach (var (tier, left) in expected)
            {
                var action = Result(1000, tier);
                BattleUtils.CalculateResistDamage(null, null, null, action);
                Assert.True(action.amount == left, Sources.Cite("KAN-II", $"{tier} on a 1000 hit leaves {left}, got {action.amount}"));
            }
        }

        [Fact]
        public void AMissOrAResistBreaksTheCombo()
        {
            foreach (var hit in new[] { HitType.Miss, HitType.Evade })
                Assert.False(Result(100, hit).ContinuesCombo(), Sources.Cite("PN120-B", $"a {hit} on the previous step breaks the combo"));
            foreach (var hit in new[] { HitType.SingleResist, HitType.DoubleResist, HitType.TripleResist, HitType.FullResist })
                Assert.False(Result(100, hit).ContinuesCombo(), Sources.Cite("BG-107403", $"a {hit} on a spell opener breaks the combo"));
            foreach (var hit in new[] { HitType.Hit, HitType.Crit })
                Assert.True(Result(100, hit).ContinuesCombo(), Sources.Cite("PN120-B", $"a landed {hit} continues the combo"));
        }

        [Fact]
        public void APartialResistStopsTheStatusRider()
        {
            var caster = Pc(50);
            var mob = Mob(50);
            var spell = new BattleCommand(27308, "blizzard") { statusId = 228021, statusChance = 1.0f, statusDuration = 30, statusTier = 1 };
            foreach (var tier in new[] { HitType.SingleResist, HitType.DoubleResist, HitType.TripleResist })
            {
                var action = Result(100, tier);
                BattleUtils.TryStatus(caster, mob, spell, action, new CommandResultContainer());
                Assert.False(mob.statusEffects.HasStatusEffect(228021u), Sources.Cite("KAN-II", $"a {tier} means the status rider does not land"));
            }
        }

        [Fact]
        public void ParryNeedsNoShieldAndBlockNeedsOne()
        {
            var mob = Mob(30);
            var shielded = Pc(27);
            shielded.SetMod((uint)Modifier.CanBlock, 1);
            var bare = Pc(26);
            var action = Result(60, HitType.Hit);

            double parry = BattleUtils.GetParryRate(mob, shielded, null, action);
            Assert.True(parry == 0, Sources.Cite("T-27048", $"no parry with a shield, got rate {parry}"));
            double block = BattleUtils.GetBlockRate(mob, bare, null, action);
            Assert.True(block == 0, Sources.Cite("CAP-OUT", $"no block without a shield, got rate {block}"));
        }

        // 0.1% per VIT + 0.2% per Block, clamped to 20-75% blocked.
        [Theory]
        [InlineData(100, 100, 700)]
        [InlineData(0, 0, 800)]
        [InlineData(0, 500, 250)]
        public void BlockReductionPerPointIsClampedTo20To75Percent(int vit, int blockStat, int left)
        {
            var mob = Mob(50);
            var pc = Pc(50);
            pc.SetMod((uint)Modifier.CanBlock, 1);
            pc.SetMod((uint)Modifier.Vitality, vit);
            pc.SetMod((uint)Modifier.Block, blockStat);
            var action = Result(1000, HitType.Block);
            BattleUtils.CalculateBlockDamage(mob, pc, null, action);
            Assert.True(action.amount == left, Sources.Cite("BG-439", $"block of 1000 with {vit} VIT and {blockStat} Block leaves {left}, got {action.amount}"));
        }
    }
}
