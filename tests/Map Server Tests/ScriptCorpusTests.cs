using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    /// <summary>Every game script loads the same way under both engines: same load errors, same
    /// globals defined. GM commands describe themselves the same way.</summary>
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

            // A main chunk that needs the running server (GetWorldManager() at load) fails under both;
            // what matters is that they fail or succeed together.
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
