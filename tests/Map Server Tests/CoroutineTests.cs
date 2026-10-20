using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    /// <summary>The wait protocol (yield "_WAIT_*") and script errors behave alike under both engines,
    /// and LuaEngine's timer and signals wake waiting scripts on time.</summary>
    [Collection("engines")]
    public sealed class CoroutineTests
    {
        private readonly EngineFixture engines;
        const string Path = "./scripts/__tests/coroutines.lua";

        public CoroutineTests(EngineFixture engines)
        {
            this.engines = engines;
        }

        public static IEnumerable<object[]> EngineNames() => new[] { new object[] { "moonsharp" }, new object[] { "xlua" } };

        private ScriptEngine Engine(string name) => name == "xlua" ? engines.XLua : engines.MoonSharp;

        [Theory]
        [MemberData(nameof(EngineNames))]
        public void YieldProtocol(string engineName)
        {
            var probe = new Probe();
            var co = Engine(engineName).Load(Path).CreateCoroutine("flow");

            var r = co.Resume(probe, "b");
            Assert.True(r.Yielded);
            Assert.Equal(new object[] { "_WAIT_TIME", 0.25 }, r.Values);

            r = co.Resume(11.0);
            Assert.Equal(new object[] { "_WAIT_SIGNAL", "go" }, r.Values);

            r = co.Resume("x", null);
            Assert.True(r.Yielded);
            Assert.Equal("_WAIT_EVENT", r[0]);
            Assert.Same(probe, r[1]);

            r = co.Resume(true);
            Assert.False(r.Yielded);
            Assert.True(co.IsDead);
            Assert.Equal(new object[] { "done", "b", 11.0, "x", null, true }, r.Values);
        }

        [Theory]
        [MemberData(nameof(EngineNames))]
        public void ScriptErrorsCarryFileAndLine(string engineName)
        {
            var script = Engine(engineName).Load(Path);
            var e = Assert.Throws<LuaScriptException>(() => script.CreateCoroutine("boom").Resume());
            Assert.Contains("coroutines.lua", e.DecoratedMessage);
            // xLua: "coroutines.lua:11: ..."; MoonSharp: "coroutines.lua:(11,4-14): ..."
            Assert.Matches(@"coroutines\.lua:\(?11[,:]", e.DecoratedMessage);

            var late = script.CreateCoroutine("boomAfterYield");
            Assert.True(late.Resume().Yielded);
            var e2 = Assert.Throws<LuaScriptException>(() => late.Resume());
            Assert.Contains("late failure", e2.DecoratedMessage);

            // A plain call that errors returns null (and logs), as LuaScript.Call did.
            Assert.Null(script.Call("boom"));
        }

        [Theory]
        [MemberData(nameof(EngineNames))]
        public void TimerWakesWaitOnTime(string engineName)
        {
            ScriptEngine.Use(Engine(engineName));
            var lua = LuaEngine.GetInstance();
            var probe = new Probe();
            var co = Engine(engineName).Load(Path).CreateCoroutine("sleeper");

            long start = Environment.TickCount64;
            lua.ResolveResume(null, co, co.Resume(probe, 0.2));
            Assert.True(probe.WaitForMarks(1, 2000), "wait(0.2) never resumed");
            long elapsed = probe.MarkTimes[0] - start;

            // The timer pulses every 50 ms; Windows timers are coarser (~15.6 ms), and shared CI
            // runners add scheduling delay. Late by more than two pulses would be a real fault.
            Assert.InRange(elapsed, 195, 200 + 50 + 100);
        }

        [Theory]
        [MemberData(nameof(EngineNames))]
        public void SignalWakesWaiter(string engineName)
        {
            ScriptEngine.Use(Engine(engineName));
            var lua = LuaEngine.GetInstance();
            var probe = new Probe();
            string signal = "test-" + engineName + "-" + Guid.NewGuid();
            var co = Engine(engineName).Load(Path).CreateCoroutine("waiter");

            lua.ResolveResume(null, co, co.Resume(probe, signal));
            Assert.Equal(0, probe.Marks);
            lua.OnSignal(signal);
            Assert.Equal(1, probe.Marks);
            Assert.True(co.IsDead);
        }
    }
}
