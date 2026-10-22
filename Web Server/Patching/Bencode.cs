/*
===========================================================================
Copyright (C) 2015-2019 Project Meteor Dev Team

This file is part of Project Meteor Server.

Project Meteor Server is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Project Meteor Server is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with Project Meteor Server. If not, see <https:www.gnu.org/licenses/>.
===========================================================================
*/

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Meteor.Web.Patching
{
    // BitTorrent's bencode: integers (long), byte strings (byte[]), lists (List<object>) and
    // dictionaries (Dictionary<string, object>, keys as Latin-1 text).
    static class Bencode
    {
        // Decodes one value. infoStart/infoEnd give the byte span of the top-level "info" value,
        // which the info hash is taken over.
        public static object Decode(byte[] data, out int infoStart, out int infoEnd)
        {
            infoStart = -1;
            infoEnd = -1;
            int pos = 0;
            object value = Read(data, ref pos, 0, ref infoStart, ref infoEnd);
            if (pos != data.Length)
                throw new InvalidDataException("bytes after the bencoded value");
            return value;
        }

        static object Read(byte[] data, ref int pos, int depth, ref int infoStart, ref int infoEnd)
        {
            if (pos >= data.Length)
                throw new InvalidDataException("bencode ends early");
            byte c = data[pos];
            if (c == 'i')
            {
                int end = Array.IndexOf(data, (byte)'e', pos);
                if (end < 0)
                    throw new InvalidDataException("unterminated integer");
                long n = long.Parse(Encoding.ASCII.GetString(data, pos + 1, end - pos - 1));
                pos = end + 1;
                return n;
            }
            if (c == 'l')
            {
                pos++;
                List<object> list = new List<object>();
                while (pos < data.Length && data[pos] != 'e')
                    list.Add(Read(data, ref pos, depth + 1, ref infoStart, ref infoEnd));
                pos++;
                return list;
            }
            if (c == 'd')
            {
                pos++;
                Dictionary<string, object> dict = new Dictionary<string, object>(StringComparer.Ordinal);
                while (pos < data.Length && data[pos] != 'e')
                {
                    string key = Encoding.Latin1.GetString((byte[])Read(data, ref pos, depth + 1, ref infoStart, ref infoEnd));
                    int start = pos;
                    dict[key] = Read(data, ref pos, depth + 1, ref infoStart, ref infoEnd);
                    if (depth == 0 && key == "info")
                    {
                        infoStart = start;
                        infoEnd = pos;
                    }
                }
                pos++;
                return dict;
            }
            if (c >= '0' && c <= '9')
            {
                int colon = Array.IndexOf(data, (byte)':', pos);
                if (colon < 0)
                    throw new InvalidDataException("bad string length");
                int length = int.Parse(Encoding.ASCII.GetString(data, pos, colon - pos));
                if (colon + 1 + length > data.Length)
                    throw new InvalidDataException("string runs past the end");
                byte[] bytes = new byte[length];
                Buffer.BlockCopy(data, colon + 1, bytes, 0, length);
                pos = colon + 1 + length;
                return bytes;
            }
            throw new InvalidDataException("bad bencode byte 0x" + c.ToString("x2"));
        }

        // Writes a dictionary with sorted keys, as bencode requires.
        public static byte[] EncodeDictionary(SortedDictionary<string, object> dict)
        {
            using (MemoryStream stream = new MemoryStream())
            {
                Write(stream, dict);
                return stream.ToArray();
            }
        }

        static void Write(MemoryStream stream, object value)
        {
            switch (value)
            {
                case long n:
                    WriteAscii(stream, "i" + n + "e");
                    break;
                case int n:
                    WriteAscii(stream, "i" + n + "e");
                    break;
                case string text:
                    WriteBytes(stream, Encoding.UTF8.GetBytes(text));
                    break;
                case byte[] bytes:
                    WriteBytes(stream, bytes);
                    break;
                case SortedDictionary<string, object> dict:
                    stream.WriteByte((byte)'d');
                    foreach (KeyValuePair<string, object> pair in dict)
                    {
                        WriteBytes(stream, Encoding.Latin1.GetBytes(pair.Key));
                        Write(stream, pair.Value);
                    }
                    stream.WriteByte((byte)'e');
                    break;
                default:
                    throw new ArgumentException("can't bencode " + value?.GetType().Name);
            }
        }

        static void WriteBytes(MemoryStream stream, byte[] bytes)
        {
            WriteAscii(stream, bytes.Length + ":");
            stream.Write(bytes, 0, bytes.Length);
        }

        static void WriteAscii(MemoryStream stream, string text)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(text);
            stream.Write(bytes, 0, bytes.Length);
        }
    }
}
