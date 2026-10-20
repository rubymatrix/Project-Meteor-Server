using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests
{
    /// <summary>The same scripts and probes under MoonSharp and xLua must agree, except where
    /// MoonSharp departs from Lua (listed, with Lua's answer expected from LuaJIT).</summary>
    [Collection("engines")]
    public sealed class EngineParityTests
    {
        private readonly EngineFixture engines;
        private readonly ITestOutputHelper output;

        public EngineParityTests(EngineFixture engines, ITestOutputHelper output)
        {
            this.engines = engines;
            this.output = output;
        }

        const string ProbePath = "./scripts/__tests/probe.lua";

        private static Dictionary<string, string> Lines(string text) =>
            text.Split('\n').Select(l => l.Split(" = ", 2)).ToDictionary(p => p[0], p => p.Length > 1 ? p[1] : "");

        private Dictionary<string, string> Run(ScriptEngine engine, string function, params object[] args)
        {
            var script = engine.Load(ProbePath);
            Assert.Null(script.LoadError);
            var result = script.Call(function, args);
            Assert.NotNull(result);
            return Lines((string)result[0]);
        }

        [Fact]
        public void InteropConversionsMatch()
        {
            var ms = Run(engines.MoonSharp, "interop", new Probe());
            var xl = Run(engines.XLua, "interop", new Probe());
            // Expected engine differences in C# interop, each with the reason.
            var known = new Dictionary<string, string>
            {
                // C# strings arrive as UTF-8: Lua's # counts bytes, MoonSharp counted chars.
                ["string ret len"] = "Lua: 6",
            };
            Compare(ms, xl, known);
        }

        [Fact]
        public void LanguageMatchesExceptMoonSharpDeviations()
        {
            var ms = Run(engines.MoonSharp, "language");
            var xl = Run(engines.XLua, "language");
            // MoonSharp's departures from Lua 5.1/5.2 semantics. LuaJIT gives Lua's answer, which is
            // what scripts get from now on.
            var luaAnswers = new Dictionary<string, string>
            {
                ["7 % -3"] = "-2",            // MoonSharp used C#'s remainder (1); Lua floors
                ["-7 % 3"] = "2",             // MoonSharp: -1
                ["-7.5 % 2"] = "0.5",         // MoonSharp: -1.5
                ["#'é'"] = "2",               // Lua counts bytes; MoonSharp counted UTF-16 chars
                ["upper('é')"] = "Aé",        // Lua case-maps bytes (C locale); MoonSharp mapped Unicode
                ["1/0"] = "inf",              // MoonSharp printed .NET's Infinity
                ["-1/0"] = "-inf",
                // Lua prints numbers with %.14g; MoonSharp printed round-trip digits. Same values.
                ["10 / 3"] = "3.3333333333333",
                ["2^53"] = "9.007199254741e+15",
                ["1e15"] = "1e+15",
                ["1e16"] = "1e+16",
                ["0.1 + 0.2"] = "0.3",
                ["math.sqrt(2)"] = "1.4142135623731",
                ["math.pi"] = "3.1415926535898",
                ["math.atan2(1, -1)"] = "2.3561944901923",
                // Standard library MoonSharp lacked or got wrong.
                ["math.log10(1000)"] = "3",
                ["tonumber('0x10')"] = "16",
                ["tonumber('z', 36)"] = "35",
                ["%s nil"] = "nil",
                ["pcall error value"] = "5",  // MoonSharp lost a table error value
                // MoonSharp's bit32 casts to int with .NET's saturating conversion, so any operand
                // at or above 2^31 clamps (here to 0x7FFFFFFF & ... = 0). LuaJIT's bit is exact.
                ["bit.band(0xFFFFFFFF, 0xA0F00000) % 2^32"] = "2700083200",
            };
            foreach (var pair in luaAnswers)
                Assert.True(xl[pair.Key] == pair.Value, $"LuaJIT {pair.Key} = {xl[pair.Key]}, expected {pair.Value}");
            Compare(ms, xl, luaAnswers.ToDictionary(p => p.Key, p => "Lua: " + p.Value));
        }

        [Fact]
        public void PairsOrderIsEngineSpecific()
        {
            // Not an assertion of equality: documents that pairs() order differs, so scripts must not
            // depend on it (sort the keys first).
            foreach (var engine in engines.Both)
                output.WriteLine($"{engine.Name}: {engine.Load(ProbePath).Call("pairsOrder")[0]}");
        }

        private void Compare(Dictionary<string, string> ms, Dictionary<string, string> xl, Dictionary<string, string> known)
        {
            Assert.Equal(ms.Keys.OrderBy(k => k), xl.Keys.OrderBy(k => k));
            var mismatches = new List<string>();
            foreach (var key in ms.Keys)
            {
                bool same = ms[key] == xl[key];
                output.WriteLine($"{(same ? "  " : known.ContainsKey(key) ? "~ " : "! ")}{key,-40} moonsharp={ms[key],-24} xlua={xl[key]}");
                if (!same && !known.ContainsKey(key))
                    mismatches.Add($"{key}: moonsharp={ms[key]} xlua={xl[key]}");
            }
            Assert.True(mismatches.Count == 0, "Unexpected engine differences:\n" + string.Join("\n", mismatches));
        }
    }
}
