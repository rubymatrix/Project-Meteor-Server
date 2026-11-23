using System;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    [Covers("actions.enmityScale", "actions.hasStatus", "actions.basePotencyScale")]
    [Collection("engines")]
    public sealed class EnmityTests
    {
        private readonly FormulaScript lua;

        public EnmityTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // Antagonize tier, Sentinel on, expected multiplier.
        [Theory]
        [InlineData(0, false, 1.0)]
        [InlineData(1, false, 1.5)]
        [InlineData(2, false, 1.65)]
        [InlineData(0, true, 1.2)]
        [InlineData(1, true, 1.8)]
        public void EnmityScale(int antagonize, bool sentinel, double expected)
        {
            double got = lua.One("enmityScale", antagonize, sentinel);
            Assert.True(Math.Abs(got - expected) < 1e-9, Sources.Cite("CODE-ENMITY", $"Antagonize {antagonize}, Sentinel {sentinel}: {got}"));
        }

        [Theory]
        [InlineData(100, 1.0)]
        [InlineData(0, 1.0)]
        [InlineData(250, 2.5)]
        [InlineData(5, 0.1)]
        [InlineData(500, 3.0)]
        public void BasePotencyScale(int basePotency, double expected)
        {
            double got = lua.One("basePotencyScale", basePotency);
            Assert.True(Math.Abs(got - expected) < 1e-9, Sources.Cite("CODE-RATES", $"basePotency {basePotency}: {got}"));
        }
    }
}
