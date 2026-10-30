using System;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.Scripting;
using Meteor.Map.packets.send.actor.battle;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // Enmity on the mob's hate list: damage, misses, heals, fixed amounts, the spread cap and target choice.
    [Collection("engines")]
    public sealed class EngineEnmityTests : EngineHarness
    {
        public EngineEnmityTests(EngineFixture engines) { }

        private static uint Hate(BattleNpc mob, Character c) =>
            mob.hateContainer.HasHateForTarget(c) ? mob.hateContainer.GetHateList()[c].cumulativeEnmity : 0;

        private static void SetHate(BattleNpc mob, Character c, uint enmity)
        {
            mob.hateContainer.AddBaseHate(c);
            mob.hateContainer.GetHateList()[c].cumulativeEnmity = enmity;
        }

        // A physical auto-attack through the engine. hitRate 100 lands it, 0 misses it; crit, block
        // and parry are off.
        private static CommandResult Swing(Character attacker, BattleNpc mob, ushort damage, double hitRate)
        {
            var action = new CommandResult(mob.Id, 0, 0, damage)
            {
                commandType = CommandType.AutoAttack,
                actionType = ActionType.Physical,
                hitRate = hitRate,
                mitigationFromScript = true,
            };
            BattleUtils.FinishActionPhysical(attacker, mob, null, action, new CommandResultContainer());
            return action;
        }

        [Fact]
        public void DamageIsEnmityOneForOneAndAMissIsNone()
        {
            var pc = Pc(50);
            var mob = Mob(50);
            mob.hateContainer.AddBaseHate(pc);

            uint before = Hate(mob, pc);
            Swing(pc, mob, 120, 100);
            Assert.True(Hate(mob, pc) - before == 120, Sources.Cite("T-36468", $"a 120-damage hit adds 120 enmity, got {Hate(mob, pc) - before}"));

            before = Hate(mob, pc);
            Swing(pc, mob, 120, 0);
            Assert.True(Hate(mob, pc) == before, Sources.Cite("T-36468", $"a miss adds no enmity, got +{Hate(mob, pc) - before}"));
        }

        [Fact]
        public void HealEnmityIsSplitAcrossTheMobsFightingTheTarget()
        {
            var healer = Pc(50);
            var tank = Pc(50);
            tank.SetHP(1000);
            var mobA = Mob(50, x: 2);
            var mobB = Mob(50, x: -2);
            mobA.hateContainer.AddBaseHate(tank);
            mobB.hateContainer.AddBaseHate(tank);

            const int healed = 1000;
            // The heal script's enmity: 0.6 per HP restored.
            var action = new CommandResult(tank.Id, 0, 0, healed) { actionType = ActionType.Heal, enmity = (ushort)(0.6 * healed) };
            BattleUtils.FinishActionHeal(healer, tank, null, action, new CommandResultContainer());

            double expected = 0.6 * healed / 2, tol = 0.05 * healed / 2;
            foreach (var mob in new[] { mobA, mobB })
                Assert.True(Math.Abs(Hate(mob, healer) - expected) <= tol,
                    Sources.Cite("T-36468", $"each of 2 mobs gains 0.6 x {healed} / 2 = {expected} (+-{tol}), got {Hate(mob, healer)}"));
        }

        [Fact]
        public void CureOnAFullHpTargetGivesNoEnmity()
        {
            var healer = Pc(50);
            var tank = Pc(50);
            var mob = Mob(50);
            mob.hateContainer.AddBaseHate(tank);
            Assert.Equal(tank.GetMaxHP(), tank.GetHP());

            var action = new CommandResult(tank.Id, 0, 0, 300) { actionType = ActionType.Heal };
            BattleUtils.FinishActionHeal(healer, tank, null, action, new CommandResultContainer());

            Assert.True(Hate(mob, healer) == 0, Sources.Cite("PN121-B", $"Cure on a full-HP target gives 0 enmity, got {Hate(mob, healer)}"));
        }

        [Fact]
        public void FlashEnmityGoesInFullToEveryEnemyHit()
        {
            var whm = Pc(50);
            var mobs = new[] { Mob(50, x: 2), Mob(50, x: -2) };
            var flash = new BattleCommand(27350, "flash");
            foreach (var mob in mobs)
            {
                var action = new CommandResult(mob.Id, flash) { enmity = 380, actionType = ActionType.Status };
                BattleUtils.FinishActionStatus(whm, mob, flash, action, new CommandResultContainer());
            }
            foreach (var mob in mobs)
            {
                uint got = Hate(mob, whm);
                // The first entry on a list starts at 1.
                Assert.True(got >= 375 && got <= 401, Sources.Cite("T-36468", $"Flash gives 380 (375-400) to every enemy hit, not split; got {got}"));
            }
        }

        [Fact]
        public void RampartEnmityIsSplitAcrossTheEnemies()
        {
            var gla = Pc(50);
            var mobs = new[] { Mob(50, x: 2), Mob(50, x: -2) };
            foreach (var mob in mobs)
                mob.hateContainer.AddBaseHate(gla);
            var rampart = new BattleCommand(27142, "rampart");
            var action = new CommandResult(gla.Id, rampart) { enmity = 190, actionType = ActionType.Status };
            uint[] before = { Hate(mobs[0], gla), Hate(mobs[1], gla) };
            BattleUtils.FinishActionStatus(gla, gla, rampart, action, new CommandResultContainer());

            for (int i = 0; i < 2; i++)
            {
                double gain = Hate(mobs[i], gla) - before[i];
                Assert.True(Math.Abs(gain - 95) <= 0.05 * 95, Sources.Cite("T-36468", $"Rampart 190 x 1 player hit, split over 2 enemies = 95 each (+-5%), got {gain}"));
            }
        }

        [Fact]
        public void ChameleonAndFreezeTakeAFlatAmountOffEachEnemy()
        {
            var pc = Pc(50);
            var mobA = Mob(50, x: 2);
            var mobB = Mob(50, x: -2);
            SetHate(mobA, pc, 2000);
            SetHate(mobB, pc, 2000);
            mobA.hateContainer.UpdateHate(pc, -840);
            mobB.hateContainer.UpdateHate(pc, -840);
            foreach (var mob in new[] { mobA, mobB })
                Assert.True(Math.Abs(2000.0 - Hate(mob, pc) - 840) <= 0.05 * 840,
                    Sources.Cite("T-36468", $"Chameleon -840 on each enemy, not halved by a second mob: 2000 -> 1160, got {Hate(mob, pc)}"));

            var thm = Pc(50);
            SetHate(mobA, thm, 2000);
            mobA.hateContainer.UpdateHate(thm, -720);
            Assert.True(Math.Abs(2000.0 - Hate(mobA, thm) - 720) <= 0.05 * 720,
                Sources.Cite("T-36468", $"Freeze -720 flat: 2000 -> 1280, got {Hate(mobA, thm)}"));
        }

        [Fact]
        public void NobodyHoldsMoreThan27000OverTheLowest()
        {
            var tank = Pc(50);
            var other = Pc(50);
            var mob = Mob(50);
            SetHate(mob, other, 1000);
            SetHate(mob, tank, 1000);
            mob.hateContainer.UpdateHate(tank, 39000);

            Assert.True(Hate(mob, tank) <= 28000, Sources.Cite("T-36468", $"tank pushed to 40000 stores at most lowest + 27000 = 28000, got {Hate(mob, tank)}"));
            Assert.True(Hate(mob, other) == 1000, Sources.Cite("T-36468", $"the others are unchanged at 1000, got {Hate(mob, other)}"));
        }

        [Fact]
        public void EnmityDoesNotDecayWithTimeOrWithHitsTaken()
        {
            var tank = Pc(50);
            var dd = Pc(50);
            var mob = Mob(50);
            SetHate(mob, tank, 5000);
            SetHate(mob, dd, 3000);

            GameClock.Step(120_000);
            mob.hateContainer.Prune(mob);
            var hit = new CommandResult(tank.Id, 0, 0, 80) { commandType = CommandType.AutoAttack };
            tank.OnDamageTaken(mob, null, hit);
            var evade = new CommandResult(tank.Id, 0, 0, 0) { commandType = CommandType.AutoAttack, hitType = HitType.Evade };
            tank.OnDamageTaken(mob, null, evade);

            Assert.True(Hate(mob, tank) == 5000 && Hate(mob, dd) == 3000,
                Sources.Cite("T-36468", $"no decay over 120 s or from hits and evades: 5000/3000, got {Hate(mob, tank)}/{Hate(mob, dd)}"));
        }

        [Fact]
        public void TheMostHatedIsTargetedAndATieGoesToWhoeverCameFirst()
        {
            var a = Pc(50);
            var b = Pc(50);
            var mob = Mob(50);
            SetHate(mob, a, 2000);
            SetHate(mob, b, 2000);
            Assert.True(mob.hateContainer.GetMostHatedTarget() == a, Sources.Cite("T-36468", "on equal enmity the mob attacks whoever targeted it first"));

            mob.hateContainer.UpdateHate(b, 1);
            Assert.True(mob.hateContainer.GetMostHatedTarget() == b, Sources.Cite("T-36468", "the mob attacks the highest enmity"));
        }

        [Fact]
        public void AKoResetsThatPlayersEnmity()
        {
            var tank = Pc(50);
            var dd = Pc(50);
            var mob = Mob(50);
            SetHate(mob, tank, 5000);
            SetHate(mob, dd, 3000);

            tank.Die(DateTime.Now);
            mob.hateContainer.Prune(mob);

            Assert.True(Hate(mob, tank) == 0, Sources.Cite("PN118", $"a KO'd player's enmity is reset, got {Hate(mob, tank)}"));
            Assert.True(mob.hateContainer.GetMostHatedTarget() == dd, Sources.Cite("PN118", "the mob moves on to the next on its list"));
        }
    }
}
