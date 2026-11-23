using System;
using Meteor.Common;
using System.Linq;
using Meteor.Map.Actors;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.Tests.Sim;
using Xunit;

namespace Meteor.Map.Tests.Packets
{
    // What the client must receive for its UI to follow the server.
    [Collection("sim")]
    public class SyncTests
    {
        private const ushort Property = 0x0137;

        [Fact]
        public void MurmurIdMatchesTheClient()
        {
            // Seen in retail captures as the id of charaWork.property[0].
            Assert.Equal(0xE14B0CA8u, Utils.MurmurHash2("charaWork.property[0]", 0));
            Assert.Equal(0x8E9C05BEu, Utils.MurmurHash2("npcWork.hateType", 0));
        }

        [Fact]
        public void StatusPacketsCarrySlotAndId()
        {
            var one = SetActorStatusPacket.BuildPacket(7, 3, 0x5A23);
            Assert.Equal(0x0177, one.gameMessage.opcode);
            Assert.Equal(3, one.data[0]);
            Assert.Equal(0x5A23, BitConverter.ToUInt16(one.data, 2));

            var ids = Enumerable.Range(1, 25).Select(i => (ushort)i).ToArray();
            var all = SetActorStatusAllPacket.BuildPacket(7, ids);
            Assert.Equal(0x0179, all.gameMessage.opcode);
            for (int i = 0; i < 20; i++)
                Assert.Equal(ids[i], BitConverter.ToUInt16(all.data, 2 * i));
        }

        // The target window's HP bar refreshes only from stateAtQuicklyForAll sourced from the mob.
        [Fact]
        public void MobHpReachesThePlayerAfterEachHit()
        {
            using var w = SimWorld.Create(seed: 2);
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(m);
            w.Attack(p, m);
            w.Run(10);

            foreach (var hit in w.Of("action.result", p).Where(e => e.Number("amount") > 0))
            {
                var update = w.Packets.Packets
                    .Where(s => s.gameMessage.opcode == Property && s.header.sourceId == m.Id && s.header.targetId == p.Id)
                    .Select(s => new PropertyReader(s.data))
                    .Where(r => r.Targets.Contains("charaWork/stateAtQuicklyForAll") && r.Number("charaWork.parameterSave.hp[0]") == (long)hit.Number("hpAfter"));
                Assert.True(update.Any(), $"no hp {hit["hpAfter"]} update for the hit at seq {hit.Seq}");
            }
        }

        [Fact]
        public void StatusGainAndLossSetAndClearTheSlot()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            p.statusEffects.AddStatusEffect(223075, 1, 0, 30, 0);
            w.Run(31);

            var slots = w.Packets.Packets.Where(s => s.gameMessage.opcode == SetActorStatusPacket.OPCODE && s.header.sourceId == p.Id)
                .Select(s => (slot: s.data[0], id: BitConverter.ToUInt16(s.data, 2))).ToList();
            Assert.Equal(2, slots.Count);
            Assert.Equal((ushort)(223075 - 200000), slots[0].id);
            Assert.Equal(slots[0].slot, slots[1].slot);
            Assert.Equal(0, slots[1].id);
        }

        [Fact]
        public void RecastReachesTheActionMenu()
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            p.EquipAbility(2, 27103, 32, false);
            w.Run(60);
            int before = w.Packets.Packets.Count;
            p.Ability(27103, p.Id);
            w.Run(1);

            uint expected = Utils.UnixTimeStampUTC(SimWorld.Start.AddSeconds(60.1 + 60));
            var recast = w.Packets.Packets.Skip(before)
                .Where(s => s.gameMessage.opcode == Property && s.header.sourceId == p.Id)
                .Select(s => new PropertyReader(s.data))
                .FirstOrDefault(r => r.Targets.Contains("charaWork/commandDetailForSelf"));
            Assert.NotNull(recast);
            var end = recast.Number("charaWork.parameterSave.commandSlot_recastTime[0]");
            Assert.NotNull(end);
            Assert.InRange((long)end, expected - 1, expected + 1);
        }
    }

    // How results split across X18, X10 and X01 (Character.DoBattleAction).
    [Collection("sim")]
    public class ResultSplitTests
    {
        [Theory]
        [InlineData(1, new ushort[] { 0x0139 })]
        [InlineData(2, new ushort[] { 0x013A })]
        [InlineData(9, new ushort[] { 0x013A })]
        [InlineData(10, new ushort[] { 0x013B })]
        [InlineData(19, new ushort[] { 0x013B, 0x0139 })]
        [InlineData(25, new ushort[] { 0x013B, 0x013A })]
        public void EveryResultGoesOutOnceInOrder(int n, ushort[] opcodes)
        {
            using var w = SimWorld.Create();
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            int before = w.Packets.Packets.Count;
            var results = Enumerable.Range(0, n).Select(i => new CommandResult(p.Id, 30000, 0, (ushort)(i + 1))).ToList();

            m.DoBattleAction(22104, 0x19001000, results);

            var sent = w.Packets.Packets.Skip(before).Where(s => s.header.targetId == p.Id && s.gameMessage.opcode >= 0x0139 && s.gameMessage.opcode <= 0x013B).ToList();
            Assert.Equal(opcodes, sent.Select(s => s.gameMessage.opcode));
            var amounts = sent.SelectMany(s =>
            {
                int count = BitConverter.ToUInt16(s.data, 0x20);
                int at = s.gameMessage.opcode switch { 0x0139 => 0x2C, 0x013A => 0x50, _ => 0x70 };
                return Enumerable.Range(0, count).Select(i => (int)BitConverter.ToUInt16(s.data, at + 2 * i));
            });
            Assert.Equal(Enumerable.Range(1, n), amounts);
        }
    }
}
