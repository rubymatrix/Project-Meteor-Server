using System;
using System.Diagnostics;
using Meteor.Map.lua;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests
{
    /// <summary>Times the same work on both engines and prints the results; it only fails if the
    /// two engines get different answers. Run with
    /// dotnet test --filter Category=Benchmark --logger "console;verbosity=detailed".</summary>
    [Collection("engines")]
    [Trait("Category", "Benchmark")]
    public sealed class EngineBenchmarks
    {
        private readonly EngineFixture engines;
        private readonly ITestOutputHelper output;
        const string Bench = "./scripts/__tests/bench.lua";

        public EngineBenchmarks(EngineFixture engines, ITestOutputHelper output)
        {
            this.engines = engines;
            this.output = output;
        }

        private double Time(Func<object> work, int repeat, out object result)
        {
            result = work(); // a first, untimed run so start-up costs don't count
            var sw = Stopwatch.StartNew();
            for (int i = 0; i < repeat; i++)
                result = work();
            return sw.Elapsed.TotalMilliseconds / repeat;
        }

        private void Compare(string label, int repeat, Func<ScriptEngine, Func<object>> make)
        {
            object msResult, xlResult;
            double ms = Time(make(engines.MoonSharp), repeat, out msResult);
            double xl = Time(make(engines.XLua), repeat, out xlResult);
            output.WriteLine($"{label,-42} moonsharp {ms,9:F3} ms   xlua {xl,9:F3} ms   x{ms / xl,6:F1}");
            Assert.Equal(Describe(msResult), Describe(xlResult));
        }

        private static string Describe(object o) => o is object[] a ? string.Join(",", a) : o?.ToString();

        [Fact]
        public void Workloads()
        {
            output.WriteLine("xlua: " + engines.XLua.Load(Bench).Call("jitStatus")[0]);

            // Loading a script: every NPC talk, battle action and GM command starts with one.
            Compare("load quest script (requires global etc.)", 20, e => () => e.Load("./scripts/quests/man/man0l0.lua").LoadError ?? "ok");
            Compare("load GM command", 50, e => () => e.Load("./scripts/commands/gm/warp.lua").LoadError ?? "ok");
            Compare("load battle helpers (battleutils)", 20, e => () => e.Load("./scripts/battleutils.lua").LoadError ?? "ok");

            var ms = engines.MoonSharp.Load(Bench);
            var xl = engines.XLua.Load(Bench);
            LuaScript For(ScriptEngine e) => e == engines.MoonSharp ? ms : xl;
            var probe = new Probe();

            Compare("pure Lua loop, 1e6 iterations", 3, e => () => For(e).Call("pureLua", 1000000.0));
            Compare("C# call from Lua, 1e5 calls", 3, e => () => For(e).Call("interop", probe, 100000.0));
            // MoonSharp counts a table's length by walking it, which makes this very slow there, so
            // the size is kept small.
            Compare("table build + scan, 1e4 rows", 1, e => () => For(e).Call("tables", 10000.0));
            Compare("C# -> Lua call", 2000, e => () => For(e).Call("jitStatus") != null);
            Compare("coroutine create + 2 resumes", 2000, e => () =>
            {
                var co = For(e).CreateCoroutine("yielder");
                co.Resume();
                return co.Resume()[0];
            });
        }
    }
}
