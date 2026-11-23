using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using Meteor.Common;
using Newtonsoft.Json.Linq;
using NLog;
using NLog.Targets;

namespace Meteor.Map.admin
{
    // Ring buffers behind the admin API: every subpacket the map server queues for the world
    // server (out) or receives from it (in), and every log line.
    static class AdminCapture
    {
        public class PacketRecord
        {
            public long seq;
            public DateTime time;
            public string dir;
            public byte[] bytes;
            public ushort type, opcode;
            public uint source, target;
        }

        public class LogRecord
        {
            public long seq;
            public DateTime time;
            public string level, logger, message;
        }

        public static bool PacketsEnabled = false;
        public static int PacketCapacity = 20000;
        public static int LogCapacity = 10000;

        private static readonly object packetLock = new object();
        private static readonly LinkedList<PacketRecord> packets = new LinkedList<PacketRecord>();
        private static long packetSeq;

        private static readonly object logLock = new object();
        private static readonly LinkedList<LogRecord> logs = new LinkedList<LogRecord>();
        private static long logSeq;

        private static Dictionary<ushort, List<string>> sendOpcodeNames;

        public static long PacketSeq { get { lock (packetLock) return packetSeq; } }
        public static long LogSeq { get { lock (logLock) return logSeq; } }
        public static int PacketCount { get { lock (packetLock) return packets.Count; } }

        public static void Out(SubPacket sp) { Record("out", sp); }
        public static void In(SubPacket sp) { Record("in", sp); }

        private static void Record(string dir, SubPacket sp)
        {
            if (!PacketsEnabled || sp == null)
                return;
            try
            {
                var rec = new PacketRecord
                {
                    time = DateTime.Now,
                    dir = dir,
                    bytes = sp.GetBytes(),
                    type = sp.header.type,
                    opcode = sp.header.type == 0x03 ? sp.gameMessage.opcode : (ushort)0,
                    source = sp.header.sourceId,
                    target = sp.header.targetId,
                };
                lock (packetLock)
                {
                    rec.seq = ++packetSeq;
                    packets.AddLast(rec);
                    while (packets.Count > PacketCapacity)
                        packets.RemoveFirst();
                }
            }
            catch (Exception)
            {
                // A capture error must never stop a packet.
            }
        }

        public static List<PacketRecord> GetPackets(long since, int limit, Func<PacketRecord, bool> filter, bool newestFirst)
        {
            lock (packetLock)
            {
                IEnumerable<PacketRecord> q = newestFirst ? packets.Reverse() : packets;
                return q.Where(p => p.seq > since && (filter == null || filter(p))).Take(limit).ToList();
            }
        }

        public static void ClearPackets()
        {
            lock (packetLock)
                packets.Clear();
        }

        public static void AddLog(string level, string logger, string message)
        {
            lock (logLock)
            {
                logs.AddLast(new LogRecord { seq = ++logSeq, time = DateTime.Now, level = level, logger = logger, message = message });
                while (logs.Count > LogCapacity)
                    logs.RemoveFirst();
            }
        }

        public static List<LogRecord> GetLogs(long since, int limit, Func<LogRecord, bool> filter, bool newestFirst)
        {
            lock (logLock)
            {
                IEnumerable<LogRecord> q = newestFirst ? logs.Reverse() : logs;
                return q.Where(l => l.seq > since && (filter == null || filter(l))).Take(limit).ToList();
            }
        }

        public static void InstallLogTarget()
        {
            var config = LogManager.Configuration;
            if (config == null)
                return;
            config.AddRuleForAllLevels(new AdminLogTarget { Name = "adminRing" }, "*");
            LogManager.ReconfigExistingLoggers();
        }

        // Opcode -> builder class names, from every Packets/Send class with a const OPCODE.
        public static Dictionary<ushort, List<string>> SendOpcodeNames
        {
            get
            {
                if (sendOpcodeNames != null)
                    return sendOpcodeNames;
                var map = new Dictionary<ushort, List<string>>();
                foreach (Type t in typeof(AdminCapture).Assembly.GetTypes())
                {
                    if (t.Namespace == null || t.Namespace.IndexOf(".send", StringComparison.OrdinalIgnoreCase) < 0)
                        continue;
                    FieldInfo f = t.GetField("OPCODE", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
                    if (f == null || !f.IsLiteral)
                        continue;
                    ushort op;
                    try { op = Convert.ToUInt16(f.GetRawConstantValue()); }
                    catch { continue; }
                    if (!map.TryGetValue(op, out var names))
                        map[op] = names = new List<string>();
                    names.Add(t.Name);
                }
                foreach (var l in map.Values)
                    l.Sort();
                return sendOpcodeNames = map;
            }
        }

        public static string OpcodeName(string dir, ushort type, ushort opcode)
        {
            if (type != 0x03 || dir != "out")
                return null;
            return SendOpcodeNames.TryGetValue(opcode, out var names) ? string.Join("|", names) : null;
        }

        // Printable ASCII runs (>= 4 chars) in a payload: chat text, names, lua paths.
        public static List<string> AsciiRuns(byte[] data, int offset)
        {
            var runs = new List<string>();
            var sb = new StringBuilder();
            for (int i = offset; i <= data.Length; i++)
            {
                if (i < data.Length && data[i] >= 0x20 && data[i] < 0x7F)
                {
                    sb.Append((char)data[i]);
                    continue;
                }
                if (sb.Length >= 4)
                    runs.Add(sb.ToString());
                sb.Clear();
            }
            return runs;
        }

        public static JObject PacketToJson(PacketRecord p, bool full)
        {
            int headerLen = SubPacket.SUBPACKET_SIZE + (p.type == 0x03 ? SubPacket.GAMEMESSAGE_SIZE : 0);
            var payload = new byte[Math.Max(0, p.bytes.Length - headerLen)];
            Array.Copy(p.bytes, headerLen, payload, 0, payload.Length);

            var o = new JObject
            {
                ["seq"] = p.seq,
                ["time"] = p.time.ToString("HH:mm:ss.fff"),
                ["dir"] = p.dir,
                ["type"] = Hex(p.type, 2),
                ["source"] = Hex(p.source, 8),
                ["target"] = Hex(p.target, 8),
                ["size"] = p.bytes.Length,
            };
            if (p.type == 0x03)
                o["opcode"] = Hex(p.opcode, 4);
            string name = OpcodeName(p.dir, p.type, p.opcode);
            if (name != null)
                o["name"] = name;
            o["payload"] = ToHex(payload);
            var ascii = AsciiRuns(payload, 0);
            if (ascii.Count > 0)
                o["ascii"] = new JArray(ascii);
            if (full)
                o["raw"] = ToHex(p.bytes);
            return o;
        }

        public static string Hex(ulong v, int digits) { return "0x" + v.ToString("X" + digits); }

        public static string ToHex(byte[] b, int max = int.MaxValue)
        {
            int n = Math.Min(b.Length, max);
            var sb = new StringBuilder(n * 2);
            for (int i = 0; i < n; i++)
                sb.Append(b[i].ToString("x2"));
            if (n < b.Length)
                sb.Append("...");
            return sb.ToString();
        }

        public static byte[] FromHex(string s)
        {
            if (s == null)
                return new byte[0];
            var clean = new StringBuilder();
            foreach (char c in s.Replace("0x", "").Replace("0X", ""))
                if (Uri.IsHexDigit(c))
                    clean.Append(c);
            if (clean.Length % 2 != 0)
                throw new ArgumentException("hex string has an odd number of digits");
            var bytes = new byte[clean.Length / 2];
            for (int i = 0; i < bytes.Length; i++)
                bytes[i] = Convert.ToByte(clean.ToString(i * 2, 2), 16);
            return bytes;
        }
    }

    [Target("AdminRing")]
    sealed class AdminLogTarget : Target
    {
        protected override void Write(LogEventInfo e)
        {
            string msg = e.FormattedMessage;
            if (e.Exception != null)
                msg += " | " + e.Exception.GetType().Name + ": " + e.Exception.Message;
            AdminCapture.AddLog(e.Level.Name, e.LoggerName, msg);
        }
    }
}
