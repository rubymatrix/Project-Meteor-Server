using System;
using System.Linq;
using Meteor.Map.Actors;
using Meteor.Map.actors.area;
using Meteor.Map.AI;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.packets.send.actor;
using Meteor.Map.Content;
using Meteor.Map.Scripting;
using Xunit;

namespace Meteor.Map.Tests
{
    // Shared set-up: a zone with no client and no database, battle npcs made in memory, and a
    // stepped game clock.
    public abstract class ContentHarness : IDisposable
    {
        internal readonly Zone zone;

        protected ContentHarness()
        {
            GameClock.SetManual(1_000_000);
            ContentManager.Reset();
            ScriptRuntime.Reset();
            EventBus.Clear();
            Factions.Reset();
            ScriptRuntime.Instance.Call("rt_ready");
            zone = new Zone(9001, "testZone", 1, "/Area/Zone/ZoneMasterTest", 0, 0, 0, false, false, false, false, false);
            Encounter.SpawnFactory = (pool, area, x, y, z, rot, level, kind) =>
            {
                var cls = new ActorClass(2104102, "/Chara/Npc/Monster/Bat/BatNormalStandard", 0, 0, null, 0, 0, 0);
                BattleNpc npc = kind == "ally"
                    ? new Ally(area.AllocateActorNumber(), cls, "testAlly", area, x, y, z, rot, 0, 0, null)
                    : new BattleNpc(area.AllocateActorNumber(), cls, "testMob", area, x, y, z, rot, 0, 0, null);
                npc.charaWork.parameterSave.state_mainSkillLevel = (short)level;
                npc.SetMod((uint)Meteor.Map.actors.chara.Modifier.Hp, 1000);
                return npc;
            };
        }

        public virtual void Dispose()
        {
            ContentManager.Reset();
            GameClock.SetAutomatic();
        }

        internal void Run(double seconds)
        {
            for (double t = 0; t < seconds; t += 0.1)
            {
                GameClock.Step(100);
                ContentManager.BeginTick();
                foreach (var e in ContentManager.Encounters.ToList())
                    foreach (var c in e.Roster())
                        c.Brain?.Update(DateTime.Now);
                ContentManager.TickArea(zone);
                ContentManager.EndTick();
            }
        }

        internal Encounter Start(string name, string variant = "")
        {
            var r = ScriptRuntime.Instance.Call("rt_try", "rt_content_launch", name, variant, zone, null, null);
            var enc = r?.FirstOrDefault() as Encounter;
            Assert.True(enc != null, ScriptRuntime.Instance.Call("rt_last_error")?.FirstOrDefault() as string);
            return enc;
        }

        internal static string LastError() => ScriptRuntime.Instance.Call("rt_last_error")?.FirstOrDefault() as string;

        internal static void Kill(Character c) => c.DelHP(c.GetHP());
    }

    [Collection("engines")]
    public sealed class ContentRuntimeTests : ContentHarness
    {
        public ContentRuntimeTests(EngineFixture engines) { }

        private Encounter Launch(string variant = "")
        {
            var check = ScriptRuntime.Instance.Call("rt_check", "__tests/content/probe");
            Assert.True(check == null || check.Length == 0 || check[0] == null, check?[0] as string);
            var r = ScriptRuntime.Instance.Call("rt_try", "rt_content_launch", "__tests/content/probe", variant, zone, null, null);
            var enc = r?.FirstOrDefault() as Encounter;
            Assert.True(enc != null && enc.Roster().Count == 2, ScriptRuntime.Instance.Call("rt_last_error")?.FirstOrDefault() as string);
            return enc;
        }

        [Fact]
        public void PhasesTasksTriggersAndObjectivesRunToAWin()
        {
            var enc = Launch("two");
            Run(4);
            Assert.Equal(EncounterState.Ending, enc.State);
            Assert.Equal("win", enc.Result);
            var log = ScriptRuntime.Instance.Call("rt_call", enc.ScriptId, "report")?.FirstOrDefault() as string;
            Assert.Equal("start,waited,burn1,poked,end:win:hits", log);
        }

        [Fact]
        public void HazardHitsWhoIsInside()
        {
            var enc = Launch("two");
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            int foeHp = foe.GetHP(), friendHp = friend.GetHP();
            Run(4);
            Assert.Equal(foeHp - 7, foe.GetHP());
            Assert.Equal(friendHp, friend.GetHP());
        }

        [Fact]
        public void ProfilesLayerAndOverride()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            var foeKinds = foe.Brain.Behaviors.Select(b => b.Kind).ToList();
            Assert.Contains("Combat", foeKinds);
            Assert.Contains("Leash", foeKinds);
            Assert.DoesNotContain("Roam", foeKinds);
            Assert.DoesNotContain("Detect", foeKinds);
            Assert.True(foe.HasTag("target"));
            Assert.Equal(new[] { "Assist", "Avoid", "Combat", "Follow", "Idle" }, friend.Brain.Behaviors.Select(b => b.Kind).OrderBy(k => k).ToArray());
            Assert.Equal(Factions.Monster, foe.factionId);
            Assert.Equal(Factions.PlayerAlly, friend.factionId);
            Assert.True(Factions.IsHostile(foe, friend));
        }

        [Fact]
        public void LinkHateWithEnmityLeavesTheFoeUnclaimed()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            foe.hateContainer.AddLinkHate(friend, 5000);
            Assert.Equal(Meteor.Map.Actors.Chara.NpcWork.HATE_TYPE_ENGAGED, ((BattleNpc)foe).npcWork.hateType);
            Assert.Equal(5000u, foe.hateContainer.GetHateList()[friend].cumulativeEnmity);
        }

        [Fact]
        public void AnActorPassedInAnOverrideReachesTheBrainAsTheActor()
        {
            var enc = Launch("led");
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            Assert.Same(foe, friend.Brain.GetBb("leader"));
        }

        [Fact]
        public void ReadyDrawsOnTheLeadersFoeAndStrikesOnlyOnceThereIsHate()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            var leader = Encounter.SpawnFactory(0, zone, foe.positionX + 20, foe.positionY, foe.positionZ, 0, 1, "ally");
            leader.target = foe;
            leader.currentMainState = SetActorStatePacket.MAIN_STATE_ACTIVE;
            friend.Brain.Remove("Assist");
            friend.Brain.SetBb("leader", leader);
            friend.Brain.Add("Ready", "Ready", new ScriptParams());
            Run(0.5);
            Assert.Equal("Ready", friend.Brain.OwnerOf(Channels.Move)?.Kind);
            Assert.Equal(SetActorStatePacket.MAIN_STATE_ACTIVE, friend.GetState());
            Assert.Empty(friend.hateContainer.GetHateList());
            Assert.IsNotType<AttackState>(friend.aiContainer.GetCurrentState());

            friend.hateContainer.AddBaseHate(foe);
            Run(0.5);
            Assert.Equal("Combat", friend.Brain.OwnerOf(Channels.Move)?.Kind);
            Assert.IsType<AttackState>(friend.aiContainer.GetCurrentState());

            friend.hateContainer.ClearHate();
            leader.currentMainState = SetActorStatePacket.MAIN_STATE_PASSIVE;
            Run(0.5);
            Assert.Equal(SetActorStatePacket.MAIN_STATE_PASSIVE, friend.GetState());
        }

        [Fact]
        public void CharmSwitchesSidesFollowsTheCharmerAndUndoesItAll()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            var leader = Encounter.SpawnFactory(0, zone, 0, 0, 0, 0, 1, "ally");
            friend.Brain.SetBb("leader", leader);
            int faction = friend.factionId;
            var charm = new ScriptParams();
            charm.Set("source", foe);
            friend.Brain.Add("Charm", "charm", charm);
            Run(0.2);
            Assert.Equal(foe.factionId, friend.factionId);
            Assert.Same(foe, friend.Brain.GetBb("leader"));
            Assert.NotNull(friend.Brain.Get("charm.follow"));

            friend.Brain.Remove("charm");
            Run(0.2);
            Assert.Equal(faction, friend.factionId);
            Assert.Same(leader, friend.Brain.GetBb("leader"));
            Assert.Null(friend.Brain.Get("charm.follow"));
        }

        [Fact]
        public void AnAllysFamilyDoesNotBringBackWhatTheAllyKindTurnsOff()
        {
            var ally = Encounter.SpawnFactory(0, zone, 0, 0, 0, 0, 1, "ally");
            ally.genusId = 29;
            ally.AttachBrain();
            var kinds = ally.Brain.Behaviors.Select(b => b.Kind).ToList();
            Assert.Contains("Follow", kinds);
            Assert.DoesNotContain("Leash", kinds);
            Assert.DoesNotContain("Roam", kinds);
        }

        [Theory]
        [InlineData(false, 0, true, false)]
        [InlineData(true, 0, false, false)]
        [InlineData(true, 1, false, true)]
        public void ThePoolDecidesWhetherABattleNpcAggroesAndLinks(bool neutral, byte linkType, bool detects, bool links)
        {
            var npc = Encounter.SpawnFactory(0, zone, 0, 0, 0, 0, 1, "battlenpc");
            npc.neutral = neutral;
            npc.linkType = linkType;
            npc.AttachBrain();
            var kinds = npc.Brain.Behaviors.Select(b => b.Kind).ToList();
            Assert.Equal(detects, kinds.Contains("Detect"));
            Assert.Equal(links, kinds.Contains("Link"));
        }

        [Fact]
        public void ContentCanOverrideRelationsForItsActors()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            var friend = enc.Group("friends").Single();
            enc.SetRelation("Monster", "PlayerAlly", "ignore");
            Assert.Equal(Relation.Ignore, Factions.Between(foe, friend));
            Assert.Equal(Relation.Hostile, Factions.Between(Factions.Monster, Factions.PlayerAlly));
        }

        [Fact]
        public void ChannelsGoToTheHighestPriority()
        {
            var enc = Launch();
            var foe = enc.Group("foes").Single();
            foe.Brain.Add("Roam", "Roam", new ScriptParams());
            foe.Brain.Add("Hold", "Hold", new ScriptParams());
            Run(0.5);
            Assert.Equal("Hold", foe.Brain.OwnerOf(Channels.Move)?.Id);
            foe.Brain.Remove("Hold");
            Run(0.5);
            Assert.Equal("Roam", foe.Brain.OwnerOf(Channels.Move)?.Id);
        }

        [Fact]
        public void TimeLimitFailsTheContent()
        {
            var enc = Launch();
            enc.SetTimeLimit(1);
            Run(1.5);
            Assert.Equal("fail", enc.Result);
            Assert.Equal("time", enc.Reason);
        }
    }
}
