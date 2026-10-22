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
using System.Buffers.Binary;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Hosting;
using Microsoft.Win32.SafeHandles;

namespace Meteor.Web.Patching
{
    // Seeds the patch files to ffxivboot. BitTorrent v1 peer wire, except the handshake's protocol
    // string is "SqexPatchSystem v01" (19 bytes, same length as "BitTorrent protocol"); boot
    // drops peers that send the stock string. The seed has every piece: it sends a full bitfield,
    // unchokes, and answers piece requests from the patch file.
    class PatchSeed : BackgroundService
    {
        static readonly byte[] Protocol = Encoding.ASCII.GetBytes("SqexPatchSystem v01");
        const int MaxRequest = 128 * 1024;
        const int MaxMessage = MaxRequest + 64;
        static readonly TimeSpan IdleTimeout = TimeSpan.FromMinutes(3);

        const byte Unchoke = 1, Interested = 2, Bitfield = 5, Request = 6, Piece = 7;

        readonly byte[] peerId = MakePeerId();

        protected override async Task ExecuteAsync(CancellationToken stopping)
        {
            TcpListener listener = new TcpListener(IPAddress.Parse(ConfigConstants.OPTIONS_BINDIP), ConfigConstants.SEED_PORT);
            listener.Start();
            Program.Log.Info("Patch seed listening on {0}:{1}", ConfigConstants.OPTIONS_BINDIP, ConfigConstants.SEED_PORT);
            try
            {
                while (!stopping.IsCancellationRequested)
                {
                    TcpClient client = await listener.AcceptTcpClientAsync(stopping);
                    _ = Task.Run(() => Serve(client, stopping), stopping);
                }
            }
            catch (OperationCanceledException)
            {
            }
            finally
            {
                listener.Stop();
            }
        }

        async Task Serve(TcpClient client, CancellationToken stopping)
        {
            EndPoint remote = client.Client.RemoteEndPoint;
            long served = 0;
            PatchStore.Patch patch = null;
            using (client)
            using (CancellationTokenSource idle = CancellationTokenSource.CreateLinkedTokenSource(stopping))
            {
                try
                {
                    client.NoDelay = true;
                    NetworkStream stream = client.GetStream();
                    idle.CancelAfter(IdleTimeout);

                    // Handshake: <19> "SqexPatchSystem v01" <8 reserved> <info_hash 20> <peer_id 20>
                    byte[] hello = new byte[68];
                    await stream.ReadExactlyAsync(hello, idle.Token);
                    if (hello[0] != Protocol.Length || !hello.AsSpan(1, 19).SequenceEqual(Protocol))
                    {
                        Program.Log.Info("seed: {0} sent a foreign handshake", remote);
                        return;
                    }
                    patch = PatchStore.FindByInfoHash(hello.AsSpan(28, 20).ToArray());
                    if (patch == null || patch.PatchPath == null)
                    {
                        Program.Log.Info("seed: {0} asked for a patch this server doesn't seed", remote);
                        return;
                    }

                    byte[] reply = new byte[68];
                    reply[0] = (byte)Protocol.Length;
                    Protocol.CopyTo(reply, 1);
                    patch.InfoHash.CopyTo(reply, 28);
                    peerId.CopyTo(reply, 48);
                    await stream.WriteAsync(reply, idle.Token);
                    await SendBitfield(stream, patch, idle.Token);
                    await SendMessage(stream, Unchoke, ReadOnlyMemory<byte>.Empty, idle.Token);
                    Program.Log.Info("seed: {0} connected for {1} {2}", remote, patch.Repo, patch.Version);

                    using (SafeFileHandle file = File.OpenHandle(patch.PatchPath, FileMode.Open, FileAccess.Read, FileShare.Read, FileOptions.Asynchronous))
                    {
                        byte[] header = new byte[4];
                        byte[] message = new byte[MaxMessage];
                        while (true)
                        {
                            await stream.ReadExactlyAsync(header, idle.Token);
                            idle.CancelAfter(IdleTimeout);
                            int length = BinaryPrimitives.ReadInt32BigEndian(header);
                            if (length == 0)
                                continue;   // keep-alive
                            if (length < 0 || length > MaxMessage)
                                return;
                            await stream.ReadExactlyAsync(message.AsMemory(0, length), idle.Token);

                            switch (message[0])
                            {
                                case Interested:
                                    await SendMessage(stream, Unchoke, ReadOnlyMemory<byte>.Empty, idle.Token);
                                    break;
                                case Request:
                                    if (length != 13)
                                        return;
                                    served += await SendPiece(stream, file, patch,
                                        BinaryPrimitives.ReadInt32BigEndian(message.AsSpan(1)),
                                        BinaryPrimitives.ReadInt32BigEndian(message.AsSpan(5)),
                                        BinaryPrimitives.ReadInt32BigEndian(message.AsSpan(9)), idle.Token);
                                    break;
                                default:
                                    break;   // choke, not interested, have, bitfield, cancel: nothing to do for a seed
                            }
                        }
                    }
                }
                catch (Exception e) when (e is IOException || e is EndOfStreamException || e is SocketException || e is OperationCanceledException || e is InvalidDataException)
                {
                }
                finally
                {
                    if (patch != null)
                        Program.Log.Info("seed: {0} done with {1} {2}, {3} bytes sent", remote, patch.Repo, patch.Version, served);
                }
            }
        }

        static async Task<int> SendPiece(NetworkStream stream, SafeFileHandle file, PatchStore.Patch patch, int index, int begin, int length, CancellationToken token)
        {
            long pieceStart = (long)index * patch.PieceLength;
            long pieceSize = Math.Min(patch.PieceLength, patch.Length - pieceStart);
            if (index < 0 || index >= patch.PieceCount || begin < 0 || length <= 0 || length > MaxRequest || begin + length > pieceSize)
                throw new InvalidDataException("bad piece request");

            byte[] message = new byte[9 + length];
            message[0] = Piece;
            BinaryPrimitives.WriteInt32BigEndian(message.AsSpan(1), index);
            BinaryPrimitives.WriteInt32BigEndian(message.AsSpan(5), begin);
            int read = 0;
            while (read < length)
            {
                int n = await RandomAccess.ReadAsync(file, message.AsMemory(9 + read, length - read), pieceStart + begin + read, token);
                if (n == 0)
                    throw new InvalidDataException("patch file is shorter than its torrent");
                read += n;
            }
            await SendMessage(stream, message, token);
            return length;
        }

        static Task SendBitfield(NetworkStream stream, PatchStore.Patch patch, CancellationToken token)
        {
            byte[] bits = new byte[(patch.PieceCount + 7) / 8];
            for (int i = 0; i < patch.PieceCount; i++)
                bits[i / 8] |= (byte)(0x80 >> (i % 8));
            return SendMessage(stream, Bitfield, bits, token);
        }

        static Task SendMessage(NetworkStream stream, byte id, ReadOnlyMemory<byte> payload, CancellationToken token)
        {
            byte[] message = new byte[1 + payload.Length];
            message[0] = id;
            payload.CopyTo(message.AsMemory(1));
            return SendMessage(stream, message, token);
        }

        // message = <id><payload>; writes it with its 4-byte length prefix.
        static async Task SendMessage(NetworkStream stream, byte[] message, CancellationToken token)
        {
            byte[] length = new byte[4];
            BinaryPrimitives.WriteInt32BigEndian(length, message.Length);
            await stream.WriteAsync(length, token);
            await stream.WriteAsync(message, token);
        }

        static byte[] MakePeerId()
        {
            const string chars = "0123456789abcdefghijklmnopqrstuvwxyz";
            byte[] id = Encoding.ASCII.GetBytes("-MT0001-000000000000");
            for (int i = 8; i < 20; i++)
                id[i] = (byte)chars[RandomNumberGenerator.GetInt32(chars.Length)];
            return id;
        }
    }
}
