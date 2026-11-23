using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    [Covers("stats.levelAdjust")]
    [Collection("engines")]
    public sealed class GearTests
    {
        private const string Source = "CL-ITEMLVL";

        private readonly FormulaScript lua;

        public GearTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        // The client's calculateLevelAdjust, one row per item level band, for 1 to 7 levels over.
        [Theory]
        [InlineData(31, new[] { 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1 })]
        [InlineData(50, new[] { 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1 })]
        [InlineData(11, new[] { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3 })]
        [InlineData(30, new[] { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3 })]
        [InlineData(8, new[] { 0.9, 0.85, 0.8, 0.75, 0.7, 0.6, 0.5 })]
        [InlineData(10, new[] { 0.9, 0.85, 0.8, 0.75, 0.7, 0.6, 0.5 })]
        public void LevelPenalty(int itemLevel, double[] byLevelsOver)
        {
            for (int over = 1; over <= 7; over++)
            {
                if (itemLevel - over < 1)
                    continue;
                double got = lua.One("levelAdjust", itemLevel - over, itemLevel);
                Assert.True(System.Math.Abs(got - byLevelsOver[over - 1]) < 1e-9,
                    Sources.Cite(Source, $"item Lv{itemLevel}, {over} over: expected {byLevelsOver[over - 1]}, got {got}"));
            }
        }

        [Theory]
        [InlineData(1, 31, 0.1)]
        [InlineData(20, 50, 0.1)]
        [InlineData(1, 10, 0.5)]
        public void PenaltyStopsAtSevenLevels(int userLevel, int itemLevel, double expected)
        {
            Assert.Equal(expected, lua.One("levelAdjust", userLevel, itemLevel), 9);
        }

        [Theory]
        [InlineData(50, 50)]
        [InlineData(50, 1)]
        [InlineData(10, 10)]
        public void NoPenaltyAtOrBelowLevel(int userLevel, int itemLevel)
        {
            Assert.Equal(1.0, lua.One("levelAdjust", userLevel, itemLevel), 9);
        }
    }
}
