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
using System.Security.Cryptography;
using System.Text;

namespace Meteor.Web.Patching
{
    // The patches the server can hand to ffxivboot, from patch_dir laid out like a retail
    // downloads\ffxiv folder:
    //   <repo id>/metainfo/D<version>.torrent   (the retail torrents, unchanged)
    //   <repo id>/patch/D<version>.patch        (the files the seed serves)
    // Each torrent is signed at startup with the key whose certificate the players' ffxivboot
    // carries (Tools/PatchTool).
    static class PatchStore
    {
        public static readonly Dictionary<string, string> RepositoryIds = new Dictionary<string, string>
        {
            { "boot", "2d2a390f" },
            { "game", "48eca647" },
        };

        public class Patch
        {
            public string Repo;
            public string RepoId;
            public string Version;
            public byte[] Torrent;
            public byte[] InfoHash;
            public int PieceLength;
            public byte[] PieceHashes;   // 20 bytes per piece
            public long Length;
            public string PatchPath;     // null when the patch file is missing or the wrong size
            public string Signature;

            public int PieceCount => PieceHashes.Length / 20;
        }

        static readonly Dictionary<string, Patch> byVersion = new Dictionary<string, Patch>();
        static readonly Dictionary<string, Patch> byInfoHash = new Dictionary<string, Patch>();

        public static bool Enabled { get; private set; }

        public static void Load(string patchDir, string keyPath)
        {
            if (String.IsNullOrEmpty(patchDir))
            {
                Program.Log.Info("No patch_dir set: older installs are told they're behind but get no patches");
                return;
            }
            if (!Directory.Exists(patchDir))
            {
                Program.Log.Error("patch_dir {0} doesn't exist", patchDir);
                return;
            }

            RSA key = RSA.Create();
            try
            {
                key.ImportFromPem(File.ReadAllText(keyPath));
            }
            catch (Exception e) when (e is IOException || e is ArgumentException || e is CryptographicException)
            {
                Program.Log.Error("Can't read signing_key {0}: {1}. Patches stay off: boot would reject unsigned torrents.", keyPath, e.Message);
                return;
            }

            foreach (KeyValuePair<string, string> repo in RepositoryIds)
            {
                string metainfo = Path.Combine(patchDir, repo.Value, "metainfo");
                if (!Directory.Exists(metainfo))
                    continue;
                foreach (string torrentPath in Directory.GetFiles(metainfo, "D*.torrent"))
                {
                    try
                    {
                        Patch patch = Read(repo.Key, repo.Value, torrentPath, patchDir);
                        patch.Signature = PatchSignature.Sign(key, patch.Torrent);
                        byVersion[repo.Key + "/" + patch.Version] = patch;
                        byInfoHash[Convert.ToHexString(patch.InfoHash)] = patch;
                    }
                    catch (InvalidDataException e)
                    {
                        Program.Log.Error("{0}: {1}", torrentPath, e.Message);
                    }
                }
            }

            int seedable = byVersion.Values.Count(p => p.PatchPath != null);
            Program.Log.Info("Patches: {0} torrents signed, {1} with their patch file ready to seed", byVersion.Count, seedable);
            Enabled = byVersion.Count > 0;
        }

        public static Patch Find(string repo, string version)
        {
            return byVersion.TryGetValue(repo + "/" + version, out Patch patch) ? patch : null;
        }

        public static Patch FindByInfoHash(byte[] infoHash)
        {
            return byInfoHash.TryGetValue(Convert.ToHexString(infoHash), out Patch patch) ? patch : null;
        }

        static Patch Read(string repo, string repoId, string torrentPath, string patchDir)
        {
            byte[] torrent = File.ReadAllBytes(torrentPath);
            Dictionary<string, object> root = Bencode.Decode(torrent, out int infoStart, out int infoEnd) as Dictionary<string, object>;
            if (root == null || infoStart < 0 || !(root["info"] is Dictionary<string, object> info))
                throw new InvalidDataException("not a torrent");

            // Retail form: name "ffxiv", one file at <repo id>/patch/D<version>.patch.
            if (!(info.GetValueOrDefault("files") is List<object> files) || files.Count != 1)
                throw new InvalidDataException("expected one file in the torrent");
            Dictionary<string, object> file = (Dictionary<string, object>)files[0];
            string[] path = ((List<object>)file["path"]).Select(p => Encoding.UTF8.GetString((byte[])p)).ToArray();
            string version = Path.GetFileNameWithoutExtension(torrentPath).Substring(1);
            if (path.Length != 3 || path[0] != repoId || path[1] != "patch" || path[2] != "D" + version + ".patch")
                throw new InvalidDataException("unexpected file path " + String.Join("/", path));

            Patch patch = new Patch
            {
                Repo = repo,
                RepoId = repoId,
                Version = version,
                Torrent = torrent,
                InfoHash = SHA1.HashData(torrent.AsSpan(infoStart, infoEnd - infoStart)),
                PieceLength = (int)(long)info["piece length"],
                PieceHashes = (byte[])info["pieces"],
                Length = (long)file["length"],
            };

            string patchPath = Path.Combine(patchDir, repoId, "patch", "D" + version + ".patch");
            if (!File.Exists(patchPath))
                Program.Log.Warn("{0} {1}: no patch file at {2}; the torrent is offered but nothing seeds it", repo, version, patchPath);
            else if (new FileInfo(patchPath).Length != patch.Length)
                Program.Log.Error("{0} {1}: patch file is {2} bytes, the torrent says {3}; not seeding it", repo, version, new FileInfo(patchPath).Length, patch.Length);
            else
                patch.PatchPath = patchPath;
            return patch;
        }
    }
}
