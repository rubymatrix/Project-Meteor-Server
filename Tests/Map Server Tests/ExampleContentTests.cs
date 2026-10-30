using System.Linq;
using Meteor.Map.Content;
using Meteor.Map.Scripting;
using Xunit;

namespace Meteor.Map.Tests
{
    // Runs each example content type headless and checks the parts that need no client or
    // navmesh: spawns, phases, objectives, outcomes.
    [Collection("engines")]
    public sealed class ExampleContentTests : ContentHarness
    {
        public ExampleContentTests(EngineFixture engines) { }

        private static object Call(Encounter e, string method) => ScriptRuntime.Instance.Call("rt_call", e.ScriptId, method)?.FirstOrDefault();

        [Fact]
        public void FamilyMovesComeFromTheClassPathThenTheGenus()
        {
            ScriptRuntime.Instance.Call("require", "__tests/moves");
            string Moves(int genus, string path) => ScriptRuntime.Instance.Call("movesFor", (double)genus, path)?.FirstOrDefault() as string;
            Assert.Equal("23142,23143,23144,23145", Moves(3, "/chara/npc/monster/wolf/WolfStandard"));
            Assert.Equal("23010,23011,23012", Moves(12, "/chara/npc/monster/rodent/NuteaterStandard"));
            Assert.NotEqual(Moves(12, "/chara/npc/monster/rodent/NuteaterStandard"), Moves(12, "/chara/npc/monster/rodent/HareStandard"));
            Assert.Equal("", Moves(9999, null));
        }

        [Theory]
        [InlineData("QuestDirectorMan0g001", 3)]
        [InlineData("QuestDirectorMan0l001", 3)]
        [InlineData("QuestDirectorMan0u001", 1)]
        public void OpeningBattleIsWonWhenTheFoesFall(string director, int foes)
        {
            var enc = Start(director);
            Assert.Equal(2, enc.Group("allies").Count);
            Assert.Equal(foes, enc.Group("enemies").Count);
            foreach (var w in enc.Group("enemies"))
                Kill(w);
            Run(1);
            Assert.Equal("win", enc.Result);
        }

        [Theory]
        [InlineData("QuestDirectorMan0l101", 1, "biters", 8)]
        [InlineData("QuestDirectorMan0u102", 1, "chinchillas", 8)]
        public void CityEscortFailsWhenTheEscortFalls(string director, int escorts, string foeGroup, int foes)
        {
            var enc = Start(director);
            Assert.Equal(escorts, enc.Group("escorts").Count);
            Assert.Equal(foes, enc.Group(foeGroup).Count);
            Kill(enc.Group("escorts")[0]);
            Run(1);
            Assert.Equal("fail", enc.Result);
            Assert.Equal("escorts", enc.Reason);
        }

        [Fact]
        public void ColiseumMatchEndsWhenTheGladiatorIsGone()
        {
            var enc = Start("QuestDirectorMan0u101");
            Assert.Single(enc.Group("gladiator"));
            Kill(enc.Group("gladiator")[0]);
            Run(1);
            Assert.True(enc.IsOver);
        }

        [Fact]
        public void EscortFailsWhenAChildFalls()
        {
            var enc = Start("QuestDirectorMan0g101");
            Assert.Equal(2, enc.Group("escorts").Count);
            Assert.Equal(6, enc.Group("biters").Count);
            Kill(enc.Group("escorts")[0]);
            Run(1);
            Assert.Equal("fail", enc.Result);
            Assert.Equal("escorts", enc.Reason);
        }

        [Fact]
        public void DungeonOpensItsGateAndEndsWithItsBoss()
        {
            var enc = Start("RaidRoc0Dungeon01");
            Assert.False(enc.IsDoorOpen("gate"));
            foreach (var m in enc.Group("room1"))
                Kill(m);
            Run(1);
            Assert.True(enc.IsDoorOpen("gate"), LastError());

            var bat = enc.Group("room2")[0];
            bat.positionX = 16.2f; bat.positionY = 173.9f; bat.positionZ = 98f;
            Run(1);
            var warden = enc.Children.SingleOrDefault();
            Assert.True(warden != null, LastError());
            Kill(warden.Group("boss").Single());
            Run(12);
            Assert.Equal("win", warden.Result);
            Assert.Equal("win", enc.Result);
        }

        [Fact]
        public void TrialVariantsShareMechanicsWithTheirOwnNumbers()
        {
            var enc = Start("InstanceRaidHyperIfrit");
            Assert.Equal("hyper", enc.Variant);
            var boss = enc.Group("boss").Single();
            Run(1);
            Assert.Equal("p1", enc.Phase);
            boss.DelHP(boss.GetMaxHP() / 2);
            Run(1);
            Assert.Equal("nails", enc.Phase);
            Assert.Equal(4, enc.Group("nails").Count);
            foreach (var n in enc.Group("nails"))
                Kill(n);
            Run(6);
            Assert.True(enc.Phase == "p2", LastError());
        }

        [Fact]
        public void CaravanChocoboDropsAPackWhenItBolts()
        {
            var enc = Start("CaravanGuardTranquil");
            var birds = enc.Group("chocobo");
            Assert.Equal(3, birds.Count);
            Assert.Equal(6.0, Call(enc, "cargo"));
            birds[0].DelHP(birds[0].GetMaxHP() * 3 / 4);
            Run(1);
            Assert.True(LastError() == null, LastError());
            Assert.Equal(5.0, Call(enc, "cargo"));
            Assert.Equal(1.0, enc.Counter("packsLost"));
        }

        [Fact]
        public void HamletSendsWavesAndFallsWithItsCaches()
        {
            var enc = Start("HamletDefenseAleport");
            Assert.Equal(4, enc.Group("caches").Count);
            Assert.Equal(4, enc.Group("guards").Count);
            Run(11);
            Assert.Equal(3, enc.Group("wave1").Count);
            foreach (var c in enc.Group("caches"))
                Kill(c);
            Run(1);
            Assert.Equal("fail", enc.Result);
            Assert.Equal("caches", enc.Reason);
        }
    }
}
