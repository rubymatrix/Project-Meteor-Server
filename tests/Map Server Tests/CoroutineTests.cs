using System;
using System.Collections.Generic;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    /// <summary>Checks that scripts can pause and carry on (how wait(), waitForSignal() and NPC
    /// dialogue work), that script errors are reported, and that waiting scripts wake up on time.
    /// Each test runs on both engines.</summary>
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
            // The two engines write the line differently: "coroutines.lua:11:" and "coroutines.lua:(11,4-14):".
            Assert.Matches(@"coroutines\.lua:\(?11[,:]", e.DecoratedMessage);

            var late = script.CreateCoroutine("boomAfterYield");
            Assert.True(late.Resume().Yielded);
            var e2 = Assert.Throws<LuaScriptException>(() => late.Resume());
            Assert.Contains("late failure", e2.DecoratedMessage);

            // A normal (non-pausing) call that fails returns null and logs the error.
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

            // The timer checks every 50 ms, and test machines can run a little late, so allow up to
            // 150 ms. Later than that would be a real fault.
            Assert.InRange(elapsed, 195, 200 + 50 + 100);
        }

        /// <summary>
        /// One thread holds the zone lock and runs a script (as the zone update does for mobs) while
        /// another thread's script asks the world for a zone (which takes the zone lock). Both must
        /// finish; with separate zone and script locks the two threads would wait on each other.
        /// </summary>
        [Fact]
        public void ZoneUpdateAndScriptDoNotDeadlock()
        {
            var script = engines.XLua.Load(Path);
            var probe = new Probe();
            for (int round = 0; round < 20; round++)
            {
                var zoneUpdate = System.Threading.Tasks.Task.Run(() =>
                {
                    lock (WorldManager.ZoneLock)
                    {
                        System.Threading.Thread.Sleep(5);
                        script.Call("touchZones", probe);
                    }
                });
                var packetThread = System.Threading.Tasks.Task.Run(() => script.Call("touchZones", probe));
                Assert.True(System.Threading.Tasks.Task.WaitAll(new[] { zoneUpdate, packetThread }, 5000), "the two threads deadlocked");
            }
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
