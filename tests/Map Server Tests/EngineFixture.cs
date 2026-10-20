using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    /// <summary>Both engines, run from the test output directory (scripts/ is copied there).</summary>
    public sealed class EngineFixture
    {
        internal readonly ScriptEngine MoonSharp;
        internal readonly ScriptEngine XLua;

        public EngineFixture()
        {
            Directory.SetCurrentDirectory(AppContext.BaseDirectory);
            global::MoonSharp.Interpreter.UserData.RegisterType<Probe>();
            global::MoonSharp.Interpreter.UserData.RegisterType<ProbeKind>();
            MoonSharp = ScriptEngine.Create("moonsharp");
            XLua = ScriptEngine.Create("xlua");
        }

        internal IEnumerable<ScriptEngine> Both => new[] { MoonSharp, XLua };

        public static string ScriptsDir => Path.Combine(AppContext.BaseDirectory, "scripts");

        /// <summary>Every game script, relative to the output directory (./scripts/...).</summary>
        public static IEnumerable<string> GameScripts() =>
            Directory.EnumerateFiles(ScriptsDir, "*.lua", SearchOption.AllDirectories)
                .Select(f => "./" + Path.GetRelativePath(AppContext.BaseDirectory, f).Replace('\\', '/'))
                .Where(f => !f.StartsWith("./scripts/__tests/", StringComparison.Ordinal))
                .OrderBy(f => f, StringComparer.Ordinal);
    }

    [CollectionDefinition("engines")]
    public sealed class EngineCollection : ICollectionFixture<EngineFixture> { }

    public enum ProbeKind { None, One, Two, Three }

    /// <summary>A C# object scripts call into, covering the conversions scripts rely on.</summary>
    public sealed class Probe
    {
        public int field = 3;
        public byte[] bytes = { 7, 0, 0, 9 };
        public double Prop { get; set; } = 1.25;
        private int marks;
        public readonly List<long> MarkTimes = new List<long>();

        public string I(int v) => "int " + v;
        public string U(uint v) => "uint " + v;
        public string B(byte v) => "byte " + v;
        public string S(short v) => "short " + v;
        public string US(ushort v) => "ushort " + v;
        public string F(float v) => "float " + v.ToString(System.Globalization.CultureInfo.InvariantCulture);
        public string Dbl(double v) => "double " + v.ToString("R", System.Globalization.CultureInfo.InvariantCulture);
        public string E(ProbeKind k) => "enum " + k;
        public string O(object o) => o == null ? "null" : o.GetType().Name;
        public string Over(int a) => "Over(int)";
        public string Over(string a) => "Over(string)";
        // Player keeps int and uint overloads for quest ids that do the same thing.
        public string Quest(uint id) => "quest " + id;
        public string Quest(int id) => "quest " + id;
        public List<int> L() => new List<int> { 10, 20, 30 };
        public int[] A() => new[] { 1, 2 };
        public Dictionary<string, int> Dict() => new Dictionary<string, int> { { "a", 1 } };
        public List<Probe> Objects() => new List<Probe> { new Probe() };
        public Probe N() => null;
        public uint RetU() => 4000000000;
        public long RetL() => 1L << 40;
        public byte RetB() => 200;
        public ProbeKind RetE() => ProbeKind.Two;
        public int Params(params object[] args) => args.Length;
        public int Opt(int a, int b = 4) => a + b;
        public Probe Self() => this;
        public string Str(string s) => s + "|" + s.Length;
        public string RetStr() => "naïve";

        public void Mark()
        {
            lock (MarkTimes)
            {
                marks++;
                MarkTimes.Add(Environment.TickCount64);
            }
        }

        public int Marks { get { lock (MarkTimes) return marks; } }

        public bool WaitForMarks(int count, int timeoutMs)
        {
            var deadline = Environment.TickCount64 + timeoutMs;
            while (Environment.TickCount64 < deadline)
            {
                if (Marks >= count)
                    return true;
                Thread.Sleep(5);
            }
            return Marks >= count;
        }
    }
}
