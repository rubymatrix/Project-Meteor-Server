using System;
using System.Diagnostics;
using Meteor.Map.lua;
using Xunit;
using Xunit.Abstractions;

namespace Meteor.Map.Tests
{
    // Times common script work and prints the results, so a slowdown shows up in the CI
    // log. It only fails if a script gives the wrong answer. Run with
    // dotnet test --filter Category=Benchmark --logger "console;verbosity=detailed".
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

        private void Time(string label, int repeat, Func<object> work, object expected)
        {
            object result = work(); // a first, untimed run so start-up costs don't count
            var sw = Stopwatch.StartNew();
            for (int i = 0; i < repeat; i++)
                result = work();
            output.WriteLine($"{label,-42} {sw.Elapsed.TotalMilliseconds / repeat,9:F3} ms");
            Assert.Equal(expected, result);
        }

        [Fact]
        public void Workloads()
        {
            var bench = engines.Engine.Load(Bench);
            output.WriteLine("LuaJIT: " + bench.Call("jitStatus")[0]);

            // Loading a script: every NPC talk, battle action and GM command starts with one.
            Time("load quest script (with its requires)", 20, () => engines.Engine.Load("./scripts/Quest/Man/Man0l0.lua").LoadError, null);
            Time("load GM command", 50, () => engines.Engine.Load("./scripts/Command/Gm/Warp.lua").LoadError, null);
            Time("load battle helpers (battleutils)", 20, () => engines.Engine.Load("./scripts/BattleUtils.lua").LoadError, null);

            var probe = new Probe();
            Time("Lua loop, 1e6 steps", 3, () => bench.Call("pureLua", 1000000.0)[0], 5903373.0);
            Time("C# method called from Lua, 1e5 calls", 3, () => bench.Call("interop", probe, 100000.0)[0], 5000150000.0);
            Time("Lua table build and scan, 1e5 rows", 3, () => bench.Call("tables", 100000.0)[0], 499980000.0);
            Time("Lua function called from C#", 2000, () => bench.Call("jitStatus") != null, true);
            Time("coroutine start, pause and finish", 2000, () =>
            {
                var co = bench.CreateCoroutine("yielder");
                co.Resume();
                return co.Resume()[0];
            }, 1.0);
        }
    }
}
