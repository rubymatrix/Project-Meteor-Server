using System;
using Meteor.Map.Actors;
using Meteor.Map.actors.chara;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.packets.send.actor.battle;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // TP from landed swings, from damage taken, and what keeps or caps it.
    [Collection("engines")]
    public sealed class EngineTpTests : EngineHarness
    {
        public EngineTpTests(EngineFixture engines) { }

        private static CommandResult Result(Character target, ushort damage, HitType hit, CommandType type = CommandType.AutoAttack) =>
            new CommandResult(target.Id, 0, 0, damage) { hitType = hit, commandType = type };

        // TP a player-side attacker gains from one landed swing.
        // Lancer's Lv12 Store TP trait (+50, i.e. +5%), in the trait layer as on a real player.
        private const int LancerStoreTpTrait = 50;

        private int SwingTp(short level, short classId, int delayMs, int storeTp = 0, HitType hit = HitType.Hit, CommandType type = CommandType.AutoAttack, int traitStoreTp = 0)
        {
            var pc = Pc(level, classId);
            pc.SetMod((uint)Modifier.Delay, delayMs);
            pc.SetMod((uint)Modifier.StoreTp, storeTp);
            pc.SetStatLayer("trait", (uint)Modifier.StoreTp, traitStoreTp);
            pc.SetTp(0);
            var mob = Mob(level);
            pc.OnDamageDealt(mob, null, Result(mob, 50, hit, type));
            return pc.GetTP();
        }

        private int TakenTp(Character defender, Character attacker, ushort damage, HitType hit = HitType.Hit)
        {
            SetTp(defender, 0);
            defender.OnDamageTaken(attacker, null, Result(defender, damage, hit));
            return defender.GetTP();
        }

        [Fact]
        public void PlayerSwingTpIsDelayTimes100()
        {
            int mrd = SwingTp(26, Character.CLASSID_MRD, 4200);
            Assert.True(mrd == 420, Sources.Cite("CAP-TP", $"Lv26 MRD, 4.2-s axe: +420 per landed swing, got {mrd}"));
            int gla = SwingTp(27, Character.CLASSID_GLA, 2500);
            Assert.True(gla == 250, Sources.Cite("CAP-TP", $"Lv27 GLA, 2.5-s sword: +250, got {gla}"));
            int war = SwingTp(50, Character.CLASSID_MRD, 4000);
            Assert.True(war == 400, Sources.Cite("RCAP-IFRIT", $"Lv50 WAR, 4.0-s axe: +400, got {war}"));
        }

        [Fact]
        public void BardSwingTpWithAndWithoutStoreTp()
        {
            int plain = SwingTp(50, Character.CLASSID_ARC, 4200);
            Assert.True(plain == 420, Sources.Cite("BG-549", $"BRD 4.2-s bow: 420, got {plain}"));
            int stp = SwingTp(50, Character.CLASSID_ARC, 4200, 40);
            Assert.True(stp == 437, Sources.Cite("BG-549", $"BRD 4.2-s bow with +40 Store TP: 437, got {stp}"));
        }

        [Fact]
        public void DragoonSwingTpCarriesTheFivePercentTrait()
        {
            int beak = SwingTp(50, Character.CLASSID_LNC, 3100, 0, traitStoreTp: LancerStoreTpTrait);
            Assert.True(beak == 326, Sources.Cite("RCAP-IFRIT", $"Lv50 DRG, 3.1-s Garuda's Beak, +5% trait: +326, got {beak}"));
        }

        // DRG 3.7-s lance and 3.8-s Ifrit's Harpoon, without and with +40 Store TP.
        [Theory]
        [InlineData(3700, 0, 389)]
        [InlineData(3800, 0, 399)]
        [InlineData(3700, 40, 404)]
        [InlineData(3800, 40, 415)]
        public void DragoonSwingTpTable(int delayMs, int storeTp, int expected)
        {
            int got = SwingTp(50, Character.CLASSID_LNC, delayMs, storeTp, traitStoreTp: LancerStoreTpTrait);
            Assert.True(got == expected, Sources.Cite("BG-549", $"DRG {delayMs / 1000.0}-s weapon, +{storeTp} Store TP: {expected}, got {got}"));
        }

        [Fact]
        public void AMissedSwingAndAWeaponskillGiveTheAttackerNoTp()
        {
            int miss = SwingTp(26, Character.CLASSID_MRD, 4200, hit: HitType.Miss);
            Assert.True(miss == 0, Sources.Cite("CAP-TP", $"missed swing: +0, got {miss}"));
            int ws = SwingTp(26, Character.CLASSID_MRD, 4200, type: CommandType.WeaponSkill);
            Assert.True(ws == 0, Sources.Cite("CAP-TP", $"landed weaponskill: its user gains 0 TP, got {ws}"));
        }

        [Theory]
        [InlineData(26, 28, 24)]
        [InlineData(26, 47, 39)]
        [InlineData(26, 71, 59)]
        [InlineData(26, 102, 85)]
        [InlineData(27, 56, 44)]
        [InlineData(27, 77, 60)]
        [InlineData(27, 94, 73)]
        [InlineData(30, 238, 152)]
        [InlineData(30, 244, 156)]
        [InlineData(30, 239, 153)]
        [InlineData(50, 64, 12)]
        [InlineData(50, 87, 16)]
        [InlineData(50, 94, 17)]
        public void PlayerTpFromDamageTakenFallsWithLevel(short level, ushort damage, int expected)
        {
            int got = TakenTp(Pc(level), Mob(30), damage);
            Assert.True(got == expected, Sources.Cite("CAP-TP", $"Lv{level} hit for {damage}: +{expected} TP, got {got}"));
        }

        [Fact]
        public void TpFromDamageTakenIsTheSameForEveryHitTypeAndZeroOnAMiss()
        {
            var mob = Mob(30);
            var pc = Pc(26);
            foreach (var hit in new[] { HitType.Hit, HitType.Crit, HitType.Parry, HitType.Block })
            {
                int got = TakenTp(pc, mob, 71, hit);
                Assert.True(got == 59, Sources.Cite("CAP-TP", $"Lv26 hit for 71 ({hit}): +59 TP, got {got}"));
            }

            SetTp(pc, 0);
            SetTp(mob, 0);
            var miss = new CommandResult(pc.Id, 0, 0, 71) { commandType = CommandType.AutoAttack, actionType = ActionType.Physical, hitRate = 0, mitigationFromScript = true };
            BattleUtils.FinishActionPhysical(mob, pc, null, miss, new CommandResultContainer());
            Assert.True(miss.amount == 0 && pc.GetHP() == pc.GetMaxHP(), Sources.Cite("CAP-TP", $"a miss deals no damage, got {miss.amount}"));
            Assert.True(pc.GetTP() == 0, Sources.Cite("CAP-TP", $"a miss gives the defender no TP, got {pc.GetTP()}"));
            Assert.True(mob.GetTP() == 0, Sources.Cite("CAP-TP", $"a miss gives the attacker no TP, got {mob.GetTP()}"));
        }

        [Fact]
        public void AParriedHitStillDealsDamageAndGivesTp()
        {
            var mob = Mob(30);
            var pc = Pc(26);
            var action = Result(pc, 80, HitType.Parry);
            BattleUtils.CalculateParryDamage(mob, pc, null, action);
            Assert.True(action.amount > 0, Sources.Cite("CAP-OUT", $"a parried hit still deals damage, got {action.amount}"));

            int dmg = action.amount;
            SetTp(pc, 0);
            pc.OnDamageTaken(mob, null, action);
            int lo = (int)Math.Ceiling(0.8261 * dmg), hi = (int)Math.Ceiling(0.8298 * dmg);
            Assert.True(pc.GetTP() >= lo && pc.GetTP() <= hi, Sources.Cite("CAP-TP", $"a parried {dmg} gives Lv26 ceil({dmg} x k) = {lo}-{hi}, got {pc.GetTP()}"));
        }

        [Fact]
        public void MonsterGains300PerLandedSwing()
        {
            var pc = Pc(27);
            foreach (var hit in new[] { HitType.Hit, HitType.Crit, HitType.Block, HitType.Parry })
            {
                var mob = Mob(30);
                SetTp(mob, 0);
                mob.OnDamageDealt(pc, null, Result(pc, 60, hit));
                Assert.True(mob.GetTP() == 300, Sources.Cite("CAP-TP", $"monster landed swing ({hit}): +300, got {mob.GetTP()}"));
            }
        }

        [Fact]
        public void MonsterTpFromShieldBash()
        {
            int got = TakenTp(Mob(30, 550), Pc(27), 53);
            Assert.True(got == 167, Sources.Cite("CAP-TP", $"Lv30 550-HP mob hit by Shield Bash for 53: +167, got {got}"));
        }

        // Lv30 770 HP: k 1.71-1.91; Lv25 679 HP: k (2.494, 2.5].
        [Theory]
        [InlineData(30, 770, 100, 171, 191)]
        [InlineData(25, 679, 1000, 2495, 2500)]
        public void MonsterTpFromDamageTaken(short level, int maxHp, ushort damage, int lo, int hi)
        {
            int got = TakenTp(Mob(level, maxHp), Pc(27), damage);
            Assert.True(got >= lo && got <= hi, Sources.Cite("CAP-TP", $"Lv{level} {maxHp}-HP mob, {damage} damage: {lo}-{hi} TP, got {got} (k {got / (double)damage:F3})"));
        }

        [Fact]
        public void FieldMobTpFromDamageTaken()
        {
            int got = TakenTp(Mob(20, 437), Pc(27), 500);
            double k = got / 500.0;
            Assert.True(Math.Abs(k - 3.71) <= 0.1 * 3.71, Sources.Cite("CAP-PBL", $"~437-HP field mob: k 3.71 +-10%, got {k:F3}"));
        }

        [Fact]
        public void IfritTpFromDamageTaken()
        {
            int got = TakenTp(Mob(58, 32000), Pc(50), 1000);
            Assert.True(got >= 48 && got <= 53, Sources.Cite("RCAP-IFRIT", $"Ifrit (~32,000 HP), 1000 damage: k 0.048-0.053 -> 48-53, got {got}"));
        }

        [Fact]
        public void TpCapsAt3000()
        {
            var pc = Pc(50);
            pc.SetTp(2900);
            pc.AddTP(500);
            Assert.True(pc.GetTP() == 3000, Sources.Cite("PN120-L", $"TP stops at 3000, got {pc.GetTP()}"));
        }

        [Fact]
        public void TpIsKeptThroughKoAndRaise()
        {
            var pc = Pc(50);
            pc.SetTp(2277);
            pc.Die(DateTime.Now);
            Assert.True(pc.IsDead());
            pc.Revive(100);
            Assert.True(pc.GetTP() == 2277, Sources.Cite("RCAP-IFRIT", $"2277 TP at KO is still 2277 after the revive, got {pc.GetTP()}"));
        }
    }
}
