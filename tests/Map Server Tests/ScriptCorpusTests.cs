using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    /// <summary>Loads every game script on both engines and checks they agree: the same scripts fail
    /// to load, and each script sets up the same functions and values. Also checks that every GM
    /// command reads the same settings (permissions, parameters, description) on both.</summary>
    [Collection("engines")]
    public sealed class ScriptCorpusTests
    {
        private readonly EngineFixture engines;

        public ScriptCorpusTests(EngineFixture engines)
        {
            this.engines = engines;
        }

        public static IEnumerable<object[]> Scripts() => EngineFixture.GameScripts().Select(s => new object[] { s });

        [Theory]
        [MemberData(nameof(Scripts))]
        public void LoadsAlike(string path)
        {
            var ms = engines.MoonSharp.Load(path);
            var xl = engines.XLua.Load(path);

            // Some scripts need a running server as they load and fail here on both engines. What
            // matters is that the two engines agree.
            Assert.True((ms.LoadError == null) == (xl.LoadError == null),
                $"moonsharp: {ms.LoadError ?? "ok"}\nxlua: {xl.LoadError ?? "ok"}");

            var msGlobals = ms.DefinedGlobals();
            var xlGlobals = xl.DefinedGlobals();
            Assert.Equal(Describe(msGlobals), Describe(xlGlobals));
        }

        private static string Describe(SortedDictionary<string, string> globals) =>
            string.Join("\n", globals.Select(p => p.Key + ": " + p.Value));

        public static IEnumerable<object[]> GmCommands() =>
            EngineFixture.GameScripts().Where(s => s.StartsWith("./scripts/commands/gm/", StringComparison.Ordinal)).Select(s => new object[] { s });

        [Theory]
        [MemberData(nameof(GmCommands))]
        public void GmCommandPropertiesAlike(string path)
        {
            string Props(ScriptEngine engine)
            {
                var t = engine.Load(path).GetGlobal("properties") as LuaTableValue;
                if (t == null)
                    return "none";
                return string.Join("; ", t.Pairs.Select(p => $"{p.Key}={p.Value}").OrderBy(x => x, StringComparer.Ordinal));
            }
            Assert.Equal(Props(engines.MoonSharp), Props(engines.XLua));
        }
    }
}
