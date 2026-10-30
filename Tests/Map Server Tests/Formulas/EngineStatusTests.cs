using System;
using System.Linq;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.battle;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // StatusEffectContainer: slots, KO, crowd-control diminishing returns and the 3-s tick.
    [Collection("engines")]
    public sealed class EngineStatusTests : EngineHarness
    {
        public EngineStatusTests(EngineFixture engines) { }

        private static StatusEffect Seed(uint id, uint seconds)
        {
            var effect = Server.GetWorldManager().GetStatusEffect(id);
            Assert.NotNull(effect);
            effect.SetDuration(seconds);
            return effect;
        }

        [Fact]
        public void RegenStacksWithDivineRegen()
        {
            var pc = Pc(50);
            Assert.True(pc.statusEffects.AddStatusEffect(Seed(223180, 45), pc));
            Assert.True(pc.statusEffects.AddStatusEffect(Seed(223264, 30), pc));
            Assert.True(pc.statusEffects.HasStatusEffect(223180u) && pc.statusEffects.HasStatusEffect(223264u),
                Sources.Cite("PN121A", "Regen stacks with Divine Regen"));
        }

        [Fact]
        public void AnActorHoldsAtMost20Statuses()
        {
            var pc = Pc(50);
            var shown = SeedStatuses().Where(s => !s.GetHidden()).Select(s => (uint)s.GetStatusEffectId()).Take(21).ToList();
            Assert.Equal(21, shown.Count);
            foreach (var id in shown)
                pc.statusEffects.AddStatusEffect(Seed(id, 600), pc);

            int held = pc.statusEffects.GetStatusEffects().Count();
            Assert.True(held <= 20, Sources.Cite("CL-SCHEMA", $"at most 20 status slots, holds {held}"));
            int slots = pc.charaWork.status.Count(s => s != 0);
            Assert.True(slots <= 20, Sources.Cite("CL-SCHEMA", $"at most 20 statuses shown, shows {slots}"));
        }

        [Fact]
        public void EveryBuffIsRemovedAtKo()
        {
            var pc = Pc(50);
            uint[] buffs = { 223001, 223002, 223062, 223129, 223180, 223256, 223264 };   // quick, haste, sentinel, protect, regen, minuet, divine regen
            foreach (var id in buffs)
                pc.statusEffects.AddStatusEffect(Seed(id, 600), pc);
            Assert.Equal(buffs.Length, buffs.Count(id => pc.statusEffects.HasStatusEffect(id)));

            pc.Die(DateTime.Now);

            var left = buffs.Where(id => pc.statusEffects.HasStatusEffect(id)).ToList();
            Assert.True(left.Count == 0, Sources.Cite("RCAP-IFRIT", "every buff is removed at KO, still up: " + string.Join(", ", left)));
        }

        [Fact]
        public void TheSameCcGroupHalvesThenIsResisted()
        {
            var pc = Pc(50);
            var mob = Mob(50);
            const uint stun = 223015;
            double[] expected = { 5, 2.5, 1.25 };
            for (int i = 0; i < 4; i++)
            {
                mob.statusEffects.RemoveStatusEffect(stun);
                bool landed = mob.statusEffects.AddStatusEffect(Seed(stun, 5), pc) && mob.statusEffects.HasStatusEffect(stun);
                if (i < 3)
                {
                    Assert.True(landed, Sources.Cite("PN121-B", $"stun #{i + 1} lands"));
                    var e = mob.statusEffects.GetStatusEffectById(stun);
                    double seconds = (e.GetEndTime() - e.GetStartTime()).TotalSeconds;
                    Assert.True(Math.Abs(seconds - expected[i]) < 0.01, Sources.Cite("PN121-B", $"stun #{i + 1} inside the 30-s timer lasts {expected[i]} s, got {seconds}"));
                }
                else
                    Assert.False(landed, Sources.Cite("PN121-B", "the 4th stun inside the timer is fully resisted"));
            }
        }

        [Fact]
        public void ADotTickIsAnX01With10105AndTheDotEffect()
        {
            var mob = Mob(58);
            mob.SetMod((uint)Modifier.RegenDown, 40);
            var results = new CommandResultContainer();
            mob.statusEffects.RegenTick(DateTime.Now, results);

            var tick = results.GetList().SingleOrDefault();
            Assert.True(tick != null, Sources.Cite("RCAP-IFRIT", "a DoT tick shows one result"));
            Assert.True(tick.worldMasterTextId == 10105, Sources.Cite("RCAP-IFRIT", $"DoT tick text 10105, got {tick.worldMasterTextId}"));
            Assert.True(tick.effectId == 0x30000022, Sources.Cite("RCAP-IFRIT", $"DoT tick effect 0x30000022, got 0x{tick.effectId:X8}"));
        }

        [Fact]
        public void ARegenTickChangesHpWithNoResult()
        {
            var pc = Pc(50);
            // Mid-fight, in active mode: natural regen adds nothing.
            pc.currentMainState = SetActorStatePacket.MAIN_STATE_ACTIVE;
            pc.SetHP(1000);
            pc.SetMod((uint)Modifier.Regen, 173);
            var results = new CommandResultContainer();
            pc.statusEffects.RegenTick(DateTime.Now, results);

            Assert.True(pc.GetHP() == 1173, Sources.Cite("RCAP-IFRIT", $"Regen tick of 173: 1000 -> 1173, got {pc.GetHP()}"));
            Assert.True(results.GetList().Count == 0, Sources.Cite("RCAP-IFRIT", $"no CommandResult for a HoT tick, got {results.GetList().Count}"));
        }

        [Fact]
        public void ThaumaturgesAndConjurersRefresh3MpATick()
        {
            foreach (short cls in new short[] { Character.CLASSID_THM, Character.CLASSID_CNJ })
            {
                var pc = Pc(50, cls);
                pc.SetMP(1000);
                pc.statusEffects.RegenTick(DateTime.Now, new CommandResultContainer());
                Assert.True(pc.GetMP() - 1000 >= 3, Sources.Cite("RCAP-IFRIT", $"class {cls}: Auto-refresh +3 MP per 3-s tick, got +{pc.GetMP() - 1000}"));
            }
        }

        [Fact]
        public void OutOfCombatTheFirstTickRestores1Point5Percent()
        {
            var gla = Pc(27, Character.CLASSID_GLA);
            gla.SetMaxHP(750);
            gla.SetHP(500);
            gla.SetMaxMP(405);
            gla.SetMP(200);
            gla.statusEffects.RegenTick(DateTime.Now, new CommandResultContainer());
            Assert.True(gla.GetHP() - 500 == 11, Sources.Cite("RCAP-ULDAH", $"Lv27 GLA 750 HP, passive out of combat: +11 HP, got +{gla.GetHP() - 500}"));
            Assert.True(gla.GetMP() - 200 == 6, Sources.Cite("CAP-PBL", $"Lv27 GLA 405 MP: +6 MP, got +{gla.GetMP() - 200}"));
        }
    }
}
