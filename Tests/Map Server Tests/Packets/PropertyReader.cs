using System;
using Meteor.Common;
using System.Collections.Generic;
using System.Text;

namespace Meteor.Map.Tests.Packets
{
    // Reads a 0x0137 payload the way the client walks it: byte 0 is the length, then entries.
    // An entry byte under 0x60 is a value size, followed by the property's Murmur2 id and value.
    // A larger byte ends a group and gives its target name length.
    internal sealed class PropertyReader
    {
        public readonly Dictionary<uint, byte[]> Values = new Dictionary<uint, byte[]>();
        public readonly List<string> Targets = new List<string>();

        public PropertyReader(byte[] data)
        {
            int end = 1 + data[0];
            int pos = 1;
            while (pos < end)
            {
                byte b = data[pos++];
                if (b < 0x60)
                {
                    uint id = BitConverter.ToUInt32(data, pos);
                    var value = new byte[b];
                    Array.Copy(data, pos + 4, value, 0, b);
                    Values[id] = value;
                    pos += 4 + b;
                }
                else
                {
                    int len = b >= 0xA4 ? b - 0xA4 : b >= 0x82 ? b - 0x82 : b - 0x60;
                    Targets.Add(Encoding.ASCII.GetString(data, pos, len));
                    pos += len;
                }
            }
        }

        public long? Number(string property)
        {
            if (!Values.TryGetValue(Utils.MurmurHash2(property, 0), out var v))
                return null;
            return v.Length switch
            {
                1 => v[0],
                2 => BitConverter.ToInt16(v, 0),
                4 => BitConverter.ToUInt32(v, 0),
                _ => null,
            };
        }
    }
}
