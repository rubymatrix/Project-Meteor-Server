using System.Linq;
using Meteor.Map.Tests.Sim;
using Xunit;

namespace Meteor.Map.Tests
{
    [Collection("sim")]
    public class TelemetryTests
    {
        [Fact]
        public void OffEmitsNothing()
        {
            Assert.False(Telemetry.On);
            Assert.Equal(0, Telemetry.Emit("x", 1, 2, ("a", 1)));
        }

        [Fact]
        public void EventsNameTheirCause()
        {
            var r = new TelemetryRecorder();
            using (Telemetry.Attach(r))
            {
                long parent = Telemetry.Emit("parent", 1, 0);
                using (Telemetry.Because(parent))
                    Telemetry.Emit("child", 1, 0);
                Telemetry.Emit("after", 1, 0);
            }
            Assert.Equal(r.Of("parent").Single().Seq, r.Of("child").Single().Cause);
            Assert.Equal(0, r.Of("after").Single().Cause);
            Assert.Equal(0, Telemetry.Emit("detached", 1, 0));
        }

        [Fact]
        public void RingKeepsTheLastEventsAndFiltersByKind()
        {
            var ring = new TelemetryRing(3);
            using (Telemetry.Attach(ring))
            {
                for (int i = 0; i < 5; i++)
                    Telemetry.Emit(i % 2 == 0 ? "even" : "odd", 1, 0, ("i", i));
            }
            var all = ring.Since(0);
            Assert.Equal(new[] { 2, 3, 4 }, all.Select(e => (int)e["i"]));
            Assert.Equal(new[] { 2, 4 }, ring.Since(0, new[] { "even" }).Select(e => (int)e["i"]));
            Assert.Empty(ring.Since(all.Last().Seq));
        }

        [Fact]
        public void JsonCarriesTheEnvelope()
        {
            var r = new TelemetryRecorder();
            using (Telemetry.Attach(r))
                Telemetry.Emit("hp.change", 7, 9, ("delta", -5));
            string json = r.Events.Single().ToJson();
            foreach (var key in new[] { "\"seq\":", "\"t\":", "\"kind\":\"hp.change\"", "\"actor\":7", "\"target\":9", "\"cause\":0", "\"delta\":-5" })
                Assert.Contains(key, json);
        }

        [Fact]
        public void NamedRollsReportDieAndOutcome()
        {
            var dice = new Dice(42);
            var r = new TelemetryRecorder();
            using (Telemetry.Attach(r))
            {
                Assert.True(dice.Chance("always", 100));
                Assert.False(dice.Chance("never", 0, inclusive: false));
            }
            var rolls = r.Of("roll");
            Assert.Equal(new[] { "always", "never" }, rolls.Select(e => (string)e["name"]));
            Assert.All(rolls, e => Assert.InRange(e.Number("die"), 0, 100));
            Assert.Equal(new[] { 1L, 2L }, rolls.Select(e => (long)e["position"]));
        }

        [Fact]
        public void DamageResultsCarryTheFormulaSteps()
        {
            using var w = SimWorld.Create(seed: 9);
            var p = w.AddPlayer(2, 10);
            var m = w.AddMob(2104001, "/Chara/Npc/Monster/Lemming/LemmingStandard", 10);
            SimWorld.Durable(m);
            w.Attack(p, m);
            w.Run(1);

            var hit = w.Of("action.result", p).First();
            var steps = (System.Collections.Generic.Dictionary<string, object>)hit["steps"];
            Assert.NotNull(steps);
            foreach (var k in new[] { "base", "statRatio", "levelFactor", "defenseCut", "variance", "gapDefense" })
                Assert.True(steps.ContainsKey(k), k);
            Assert.InRange(System.Convert.ToDouble(steps["variance"]), 0.92, 1.08);
        }
    }
}
