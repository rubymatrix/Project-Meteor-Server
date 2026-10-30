using System;
using Meteor.Map.Actors;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    // KO and raise: what a revive restores and the command lock after it.
    [Collection("engines")]
    public sealed class EngineKoTests : EngineHarness
    {
        public EngineKoTests(EngineFixture engines) { }

        [Fact]
        public void AFullRaiseRestoresAllHpAndLeavesMp()
        {
            foreach (short maxHp in new short[] { 2774, 2206 })
            {
                var pc = Pc(50);
                pc.SetMaxHP((uint)maxHp);
                pc.SetHP((uint)maxHp);
                pc.SetMP(640);
                pc.DelHP(maxHp);
                Assert.True(pc.IsDead());

                pc.Revive(100);
                Assert.True(pc.GetHP() == maxHp, Sources.Cite("RCAP-IFRIT", $"Enhanced Raise: HP {maxHp}/{maxHp}, got {pc.GetHP()}"));
                Assert.True(pc.GetMP() == 640, Sources.Cite("RCAP-IFRIT", $"MP left as at KO (640), got {pc.GetMP()}"));
                Assert.True(pc.currentMainState == 0, Sources.Cite("RCAP-IFRIT", $"main state 0 after the raise, got {pc.currentMainState}"));
            }
        }

        [Fact]
        public void BattleCommandsAreLockedFor7SecondsAfterARaise()
        {
            Assert.True(Player.RaiseCommandLockSeconds == 7, Sources.Cite("PN119-B", $"no commands for 7 s after a raise, got {Player.RaiseCommandLockSeconds}"));
        }

        [Fact]
        public void TpIsKeptAcrossAKo()
        {
            var war = Pc(30);
            war.SetTp(885);
            war.Die(DateTime.Now);
            war.Revive(100);
            Assert.True(war.GetTP() == 885, Sources.Cite("CAP-WQU2", $"WAR keeps 885 TP across a KO, got {war.GetTP()}"));
        }
    }
}
