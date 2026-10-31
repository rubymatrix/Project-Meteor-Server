using System;
using Meteor.Map.packets.send.actor;
using Xunit;

namespace Meteor.Map.Tests
{
    public class HoverHeightTests
    {
        [Fact]
        public void SetActorPositionCarriesHoverInTheVectorY()
        {
            byte[] d = SetActorPositionPacket.BuildPacket(1, 0, 10f, 21.5f, 30f, 0f, 0, false, 1.5f).data;
            Assert.Equal(21.5f, BitConverter.ToSingle(d, 0x0C));
            Assert.Equal(0f, BitConverter.ToSingle(d, 0x18));
            Assert.Equal(1.5f, BitConverter.ToSingle(d, 0x1C));
            Assert.Equal(0f, BitConverter.ToSingle(d, 0x20));
        }

        [Fact]
        public void MoveActorToPositionCarriesHoverInTheVectorY()
        {
            byte[] d = MoveActorToPositionPacket.BuildPacket(1, 10f, 21.5f, 30f, 0f, 2, 1.5f).data;
            Assert.Equal(21.5f, BitConverter.ToSingle(d, 0x0C));
            Assert.Equal((ushort)2, BitConverter.ToUInt16(d, 0x18));
            Assert.Equal(0f, BitConverter.ToSingle(d, 0x20));
            Assert.Equal(1.5f, BitConverter.ToSingle(d, 0x24));
            Assert.Equal(0f, BitConverter.ToSingle(d, 0x28));
        }

        [Fact]
        public void GroundActorsSendNoHover()
        {
            Assert.Equal(0f, BitConverter.ToSingle(SetActorPositionPacket.BuildPacket(1, 0, 0f, 0f, 0f, 0f, 0, false).data, 0x1C));
            Assert.Equal(0f, BitConverter.ToSingle(MoveActorToPositionPacket.BuildPacket(1, 0f, 0f, 0f, 0f, 1).data, 0x24));
        }
    }
}
