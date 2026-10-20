using System;
using System.Diagnostics;
using Meteor.Map.lua;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests
{
    /// <summary>Timings for both engines (printed, not asserted beyond equal results). Run with
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
            result = work(); // warm-up
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

            // Script load: what every event, hook and GM command pays (fresh environment + requires).
            Compare("load quest script (requires global etc.)", 20, e => () => e.Load("./scripts/quests/man/man0l0.lua").LoadError ?? "ok");
            Compare("load GM command", 50, e => () => e.Load("./scripts/commands/gm/warp.lua").LoadError ?? "ok");
            Compare("load battle helpers (battleutils)", 20, e => () => e.Load("./scripts/battleutils.lua").LoadError ?? "ok");

            var ms = engines.MoonSharp.Load(Bench);
            var xl = engines.XLua.Load(Bench);
            LuaScript For(ScriptEngine e) => e == engines.MoonSharp ? ms : xl;
            var probe = new Probe();

            Compare("pure Lua loop, 1e6 iterations", 3, e => () => For(e).Call("pureLua", 1000000.0));
            Compare("C# call from Lua, 1e5 calls", 3, e => () => For(e).Call("interop", probe, 100000.0));
            // MoonSharp's # walks the table, so t[#t + 1] = v is quadratic there: keep n small.
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
