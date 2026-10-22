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
using System.Linq;
using System.Net;
using System.Text;

using Microsoft.AspNetCore.Http;

namespace Meteor.Web.Patching
{
    // The tracker every retail torrent names: http://track01.ffxiv.com:54997/announce.
    // Standard HTTP announce. Answers with the server's seed first, then other players fetching
    // the same patch, as compact 6-byte peers.
    static class Tracker
    {
        // Boot raises its own error for exactly this failure reason.
        const string NotAuthorized = "requested download is not authorized for use with this tracker";

        class Peer
        {
            public byte[] PeerId;
            public IPAddress Address;
            public int Port;
            public DateTime LastSeen;
        }

        static readonly Dictionary<string, List<Peer>> swarms = new Dictionary<string, List<Peer>>();
        static readonly object swarmLock = new object();

        public static IResult Announce(HttpContext context)
        {
            Dictionary<string, byte[]> query = ParseRawQuery(context.Request.QueryString.Value ?? "");
            byte[] infoHash = query.GetValueOrDefault("info_hash");
            byte[] peerId = query.GetValueOrDefault("peer_id");
            PatchStore.Patch patch = infoHash != null && infoHash.Length == 20 ? PatchStore.FindByInfoHash(infoHash) : null;
            if (patch == null || peerId == null || peerId.Length != 20)
            {
                Program.Log.Info("tracker: refused announce from {0}", context.Connection.RemoteIpAddress);
                return Reply(new SortedDictionary<string, object>(StringComparer.Ordinal) { { "failure reason", NotAuthorized } });
            }

            string evt = Text(query, "event");
            int.TryParse(Text(query, "port"), out int port);
            int.TryParse(Text(query, "numwant"), out int numWant);
            if (!query.ContainsKey("numwant"))
                numWant = 50;
            IPAddress address = context.Connection.RemoteIpAddress?.MapToIPv4();
            if (IPAddress.TryParse(Text(query, "ip"), out IPAddress given))
                address = given;

            string key = Convert.ToHexString(infoHash);
            List<byte> peers = new List<byte>();
            AddPeer(peers, ConfigConstants.SEED_ADDRESS, ConfigConstants.SEED_PORT);

            lock (swarmLock)
            {
                if (!swarms.TryGetValue(key, out List<Peer> swarm))
                    swarms[key] = swarm = new List<Peer>();
                DateTime now = DateTime.UtcNow;
                swarm.RemoveAll(p => p.PeerId.AsSpan().SequenceEqual(peerId) || now - p.LastSeen > TimeSpan.FromSeconds(ConfigConstants.TRACKER_INTERVAL * 2));
                if (evt != "stopped" && address != null && port > 0)
                    swarm.Add(new Peer { PeerId = peerId, Address = address, Port = port, LastSeen = now });

                foreach (Peer other in swarm.Where(p => !p.PeerId.AsSpan().SequenceEqual(peerId)).Take(Math.Max(0, numWant - 1)))
                    AddPeer(peers, other.Address, other.Port);
            }

            Program.Log.Info("tracker: {0} {1} {2} from {3}:{4} left={5}", patch.Repo, patch.Version,
                evt == "" ? "update" : evt, address, port, Text(query, "left"));
            return Reply(new SortedDictionary<string, object>(StringComparer.Ordinal)
            {
                { "interval", ConfigConstants.TRACKER_INTERVAL },
                { "min interval", Math.Min(60, ConfigConstants.TRACKER_INTERVAL) },
                { "peers", numWant == 0 ? Array.Empty<byte>() : peers.ToArray() },
            });
        }

        static void AddPeer(List<byte> peers, IPAddress address, int port)
        {
            if (address == null || address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
                return;
            peers.AddRange(address.GetAddressBytes());
            peers.Add((byte)(port >> 8));
            peers.Add((byte)port);
        }

        static IResult Reply(SortedDictionary<string, object> dict)
        {
            return Results.Bytes(Bencode.EncodeDictionary(dict), "text/plain");
        }

        static string Text(Dictionary<string, byte[]> query, string name)
        {
            return query.TryGetValue(name, out byte[] value) ? Encoding.ASCII.GetString(value) : "";
        }

        // info_hash and peer_id are raw bytes, percent-encoded; decode to bytes, not text.
        static Dictionary<string, byte[]> ParseRawQuery(string query)
        {
            Dictionary<string, byte[]> result = new Dictionary<string, byte[]>(StringComparer.Ordinal);
            foreach (string pair in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
            {
                int eq = pair.IndexOf('=');
                string name = eq < 0 ? pair : pair.Substring(0, eq);
                result[name] = PercentDecode(eq < 0 ? "" : pair.Substring(eq + 1));
            }
            return result;
        }

        static byte[] PercentDecode(string text)
        {
            using (MemoryStream bytes = new MemoryStream())
            {
                for (int i = 0; i < text.Length; i++)
                {
                    char c = text[i];
                    if (c == '%' && i + 2 < text.Length && Uri.IsHexDigit(text[i + 1]) && Uri.IsHexDigit(text[i + 2]))
                    {
                        bytes.WriteByte(Convert.ToByte(text.Substring(i + 1, 2), 16));
                        i += 2;
                    }
                    else
                    {
                        bytes.WriteByte(c == '+' ? (byte)' ' : (byte)c);
                    }
                }
                return bytes.ToArray();
            }
        }
    }
}
