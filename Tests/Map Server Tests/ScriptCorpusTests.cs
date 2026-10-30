using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    // Loads every game script and checks it loads without an error, and that every GM
    // command describes itself (permissions, parameters, description) in the expected form.
    [Collection("engines")]
    public sealed class ScriptCorpusTests
    {
        private readonly EngineFixture engines;

        public ScriptCorpusTests(EngineFixture engines)
        {
            this.engines = engines;
        }

        // Scripts that ask the running server for something while they load, which these tests
        // don't start. PopulaceCompanySupply looks up its quest actor (GetStaticActor).
        private static readonly HashSet<string> NeedsRunningServer = new HashSet<string>
        {
            "./scripts/Chara/Npc/Populace/PopulaceCompanySupply.lua",
        };

        // AI and content modules run inside the script runtime (Ai/Runtime/Core.lua), which
        // gives them Profile, Encounter and the rest; RuntimeModuleLoads checks them there.
        public static bool IsRuntimeModule(string path) =>
            path.StartsWith("./scripts/Ai/", StringComparison.Ordinal)
            || path.StartsWith("./scripts/Routes/", StringComparison.Ordinal)
            || path.StartsWith("./scripts/Content/", StringComparison.Ordinal);

        public static IEnumerable<object[]> Scripts() =>
            EngineFixture.GameScripts().Where(s => !NeedsRunningServer.Contains(s) && !IsRuntimeModule(s))
                .Select(s => new object[] { s });

        public static IEnumerable<object[]> RuntimeModules() =>
            EngineFixture.GameScripts().Where(s => IsRuntimeModule(s) && !s.StartsWith("./scripts/Ai/Runtime/", StringComparison.Ordinal))
                .Select(s => new object[] { s.Substring("./scripts/".Length, s.Length - "./scripts/".Length - ".lua".Length) });

        [Theory]
        [MemberData(nameof(RuntimeModules))]
        public void RuntimeModuleLoads(string name)
        {
            var r = Meteor.Map.Scripting.ScriptRuntime.Instance.Call("rt_check", name);
            string error = r != null && r.Length > 0 ? r[0] as string : null;
            Assert.True(error == null, error);
        }

        [Theory]
        [MemberData(nameof(Scripts))]
        public void Loads(string path)
        {
            var script = engines.Engine.Load(path);
            Assert.True(script.LoadError == null, script.LoadError);
        }

        // The server looks quest Man0l0 up as Quest/Man/Man0l0.lua, capitals included; a folder
        // spelled differently is found on macOS and Windows but not on Linux.
        [Fact]
        public void QuestScriptsSitUnderTheirPrefix()
        {
            var wrong = EngineFixture.GameScripts()
                .Where(s => s.StartsWith("./scripts/Quest/", StringComparison.Ordinal) && s.Count(c => c == '/') == 4)
                .Where(s => { var p = s.Split('/'); return !p[4].StartsWith(p[3], StringComparison.Ordinal) || p[3].Length != 3; })
                .ToList();
            Assert.True(wrong.Count == 0, "quest script outside Quest/<first three letters>/: " + string.Join(", ", wrong));
        }

        public static IEnumerable<object[]> GmCommands() =>
            EngineFixture.GameScripts().Where(s => s.StartsWith("./scripts/Command/Gm/", StringComparison.Ordinal)).Select(s => new object[] { s });

        [Theory]
        [MemberData(nameof(GmCommands))]
        public void GmCommandDescribesItself(string path)
        {
            var script = engines.Engine.Load(path);
            Assert.True(script.HasFunction("onTrigger"), "no onTrigger function");

            var properties = Assert.IsType<LuaTableValue>(script.GetGlobal("properties"));
            foreach (var pair in properties.Pairs)
            {
                switch (pair.Key as string)
                {
                    case "permissions":
                        Assert.IsType<double>(pair.Value);
                        break;
                    case "parameters":
                        // One letter per argument: s (text), i (whole number), d or f (number).
                        Assert.Matches("^[sidf]*$", Assert.IsType<string>(pair.Value));
                        break;
                    case "description":
                        Assert.IsType<string>(pair.Value);
                        break;
                }
            }
        }
    }
}
