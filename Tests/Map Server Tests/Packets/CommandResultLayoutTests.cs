using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.packets.send.actor.battle;
using Xunit;

namespace Meteor.Map.Tests.Packets
{
    // Offsets are where the client reads each field of each result variant.
    public class CommandResultLayoutTests
    {
        private const uint Source = 0x44000010, Anim = 0x19001000;
        private const ushort Command = 22104;

        private static CommandResult Entry(int i) =>
            new CommandResult(0x46000000u + (uint)i, (ushort)(30000 + i), 0x08000604u + (uint)i, (ushort)(100 + i), (byte)(i % 4), (byte)(1 + i % 3));

        private static void Header(byte[] d, int count)
        {
            Assert.Equal(Source, BitConverter.ToUInt32(d, 0x00));
            Assert.Equal(Anim, BitConverter.ToUInt32(d, 0x04));
            Assert.Equal(count, BitConverter.ToUInt16(d, 0x20));
            Assert.Equal(0, BitConverter.ToUInt16(d, 0x22));    // header text id: non-zero logs a line
            Assert.Equal(Command, BitConverter.ToUInt16(d, 0x24));
            // Log-only integers; int2 and int8 are 1 in every builder (the X18 list overload also sets int6).
            Assert.Equal(0x0810, BitConverter.ToUInt16(d, 0x26) & 0xFFF3);
        }

        private static void Entries(byte[] d, IList<CommandResult> list, int target, int amount, int text, int effect, int param, int hit)
        {
            for (int i = 0; i < list.Count; i++)
            {
                Assert.Equal(list[i].targetId, BitConverter.ToUInt32(d, target + 4 * i));
                Assert.Equal(list[i].amount, BitConverter.ToUInt16(d, amount + 2 * i));
                Assert.Equal(list[i].worldMasterTextId, BitConverter.ToUInt16(d, text + 2 * i));
                Assert.Equal(list[i].effectId, BitConverter.ToUInt32(d, effect + 4 * i));
                Assert.Equal(list[i].param, d[param + i]);
                Assert.Equal(list[i].hitNum, d[hit + i]);
            }
        }

        [Fact]
        public void X01()
        {
            var e = Entry(3);
            var p = CommandResultX01Packet.BuildPacket(Source, Anim, Command, e);
            Assert.Equal(0x0139, p.gameMessage.opcode);
            Assert.Equal(0x58 - 0x20, p.data.Length);
            Header(p.data, 1);
            Entries(p.data, new[] { e }, 0x28, 0x2C, 0x2E, 0x30, 0x34, 0x35);
        }

        [Theory]
        [InlineData(2)]
        [InlineData(10)]
        public void X10(int n)
        {
            var list = Enumerable.Range(0, n).Select(Entry).ToArray();
            int offset = 0;
            var p = CommandResultX10Packet.BuildPacket(Source, Anim, Command, list, ref offset);
            Assert.Equal(0x013A, p.gameMessage.opcode);
            Assert.Equal(n, offset);
            Header(p.data, n);
            Entries(p.data, list, 0x28, 0x50, 0x64, 0x78, 0xA0, 0xAA);
        }

        [Theory]
        [InlineData(10)]
        [InlineData(18)]
        public void X18(int n)
        {
            var list = Enumerable.Range(0, n).Select(Entry).ToList();
            int offset = 0;
            var p = CommandResultX18Packet.BuildPacket(Source, Anim, Command, list, ref offset);
            Assert.Equal(0x013B, p.gameMessage.opcode);
            Assert.Equal(n, offset);
            Header(p.data, n);
            Entries(p.data, list, 0x28, 0x70, 0x94, 0xB8, 0x100, 0x112);
        }

        [Fact]
        public void EachVariantTakesNoMoreThanItHolds()
        {
            var list = Enumerable.Range(0, 30).Select(Entry).ToArray();
            int offset = 0;
            CommandResultX10Packet.BuildPacket(Source, Anim, Command, list, ref offset);
            Assert.Equal(10, offset);
            CommandResultX18Packet.BuildPacket(Source, Anim, Command, list, ref offset);
            Assert.Equal(28, offset);
            var last = CommandResultX18Packet.BuildPacket(Source, Anim, Command, list, ref offset);
            Assert.Equal(30, offset);
            Assert.Equal(2, BitConverter.ToUInt16(last.data, 0x20));
            Entries(last.data, list.Skip(28).ToList(), 0x28, 0x70, 0x94, 0xB8, 0x100, 0x112);
        }
    }
}
