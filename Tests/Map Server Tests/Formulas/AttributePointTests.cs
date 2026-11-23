using System.Collections.Generic;
using System.Linq;
using Meteor.Map.Actors;
using Xunit;

namespace Meteor.Map.Tests.Formulas
{
    [Covers("stats.bonusPoints", "stats.bonusPointCap", "stats.bonusAllocation")]
    [Collection("engines")]
    public sealed class AttributePointTests
    {
        private const string Source = "PN120-B";
        private static readonly byte[] Classes = { 2, 3, 4, 7, 8, 22, 23 };

        // The level / allotment cap table in the 1.20 notes, Lv10 to Lv50.
        private static readonly int[] CapFromLevel10 =
        {
            3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13,
            13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23,
        };

        private static int OfficialCap(int level) => level < 10 ? 0 : CapFromLevel10[level - 10];

        public static IEnumerable<object[]> CapTable() =>
            Enumerable.Range(10, 41).Select(level => new object[] { level, OfficialCap(level) });

        private readonly FormulaScript lua;

        public AttributePointTests(EngineFixture engines)
        {
            lua = new FormulaScript(engines);
        }

        [Theory]
        [InlineData(1, 0)]
        [InlineData(9, 0)]
        [InlineData(10, 5)]
        [InlineData(11, 6)]
        [InlineData(30, 25)]
        [InlineData(50, 45)]
        public void PointsEarned(int level, int expected)
        {
            Assert.Equal(expected, Player.BonusPointTotal(level));
            Assert.Equal(expected, (int)lua.Call("bonusPoints", level)[0]);
        }

        [Theory]
        [MemberData(nameof(CapTable))]
        public void CapPerAttribute(int level, int expected)
        {
            Assert.True(expected == Player.BonusPointCap(level),
                Sources.Cite(Source, $"Lv{level} cap: expected {expected}, Player.BonusPointCap gives {Player.BonusPointCap(level)}"));
            int scripted = (int)lua.Call("bonusPoints", level)[1];
            Assert.True(expected == scripted,
                Sources.Cite(Source, $"Lv{level} cap: expected {expected}, stats.bonusPointCap gives {scripted}"));
        }

        [Fact]
        public void NoPointsBeforeLevelTen()
        {
            for (int level = 1; level < 10; level++)
                Assert.Equal(0, Player.BonusPointCap(level));
        }

        // A character with no player behind it spends every point, and none past the cap.
        [Fact]
        public void AutomaticSplitIsLegal()
        {
            var wrong = new List<string>();
            foreach (var classId in Classes)
                for (int level = 1; level <= 50; level++)
                {
                    var r = lua.Call("bonusAllocation", classId, level);
                    int used = (int)r[0], most = (int)r[1];
                    if (used != Player.BonusPointTotal(level) || most > OfficialCap(level))
                        wrong.Add($"class {classId} Lv{level}: used {used} of {Player.BonusPointTotal(level)}, most {most}");
                }
            Assert.True(wrong.Count == 0, Sources.Cite(Source, string.Join("\n", wrong.Take(20))));
        }
    }
}
