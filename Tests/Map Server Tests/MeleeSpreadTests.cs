using System;
using Meteor.Map.actors.chara.ai;
using Xunit;

namespace Meteor.Map.Tests
{
    public class MeleeSpreadTests
    {
        private const float Deg = (float)Math.PI / 180.0f;

        private static MeleeSpread.Member M(uint id, float bearingDeg, float dist = 6.0f, bool standing = false, float radius = 2.0f, float body = 0.5f) => new MeleeSpread.Member
        {
            Id = id,
            X = dist * MathF.Cos(bearingDeg * Deg),
            Z = dist * MathF.Sin(bearingDeg * Deg),
            Radius = radius,
            MaxRadius = 7.0f,
            Body = body,
            Standing = standing,
        };

        private static float Dist(MeleeSpread.Stop a, MeleeSpread.Stop b) => MathF.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Z - b.Z) * (a.Z - b.Z));
        private static float Shift(MeleeSpread.Stop s) => MeleeSpread.Wrap(s.Theta - s.Theta0) / Deg;

        [Fact]
        public void LoneMobStopsOnItsApproachLine()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 40) })[0];
            Assert.Equal(0f, Shift(s), 3);
            Assert.Equal(2.0f * MathF.Cos(40 * Deg), s.X, 3);
            Assert.Equal(2.0f * MathF.Sin(40 * Deg), s.Z, 3);
        }

        [Fact]
        public void TwoOnTheSameLineSplitOppositeWays()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(7, 90), M(3, 90) });
            Assert.True(Shift(s[1]) < 0, $"{Shift(s[1])}");     // lower id goes the negative way
            Assert.True(Shift(s[0]) > 0, $"{Shift(s[0])}");
            Assert.Equal(-Shift(s[0]), Shift(s[1]), 2);
            Assert.True(Dist(s[0], s[1]) >= MeleeSpread.SPACING_MIN);
        }

        [Fact]
        public void ThreeMobsSpreadWithinTheShiftCap()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 80, radius: 6.5f), M(2, 90, radius: 6.5f), M(3, 100, radius: 6.5f) });
            foreach (var x in s)
                Assert.InRange(MathF.Abs(Shift(x)), 0, 25.01f);
            Assert.True(Dist(s[0], s[1]) >= 2.6f, $"{Dist(s[0], s[1])}");
            Assert.True(Dist(s[1], s[2]) >= 2.6f, $"{Dist(s[1], s[2])}");
            Assert.InRange(Shift(s[1]), -1, 1);                  // the middle one keeps its line
            Assert.True(Shift(s[0]) < 0 && Shift(s[2]) > 0);
        }

        [Fact]
        public void MobsAlreadyApartAreLeftAlone()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 0), M(2, 120), M(3, 240) });
            foreach (var x in s)
                Assert.Equal(0f, Shift(x), 3);
        }

        [Fact]
        public void StandingMobGivesWayLessThanAnArrival()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 90, 6.5f, standing: true, radius: 6.5f), M(2, 95, radius: 6.5f) });
            Assert.True(MathF.Abs(Shift(s[0])) < MathF.Abs(Shift(s[1])), $"{Shift(s[0])} {Shift(s[1])}");
        }

        [Fact]
        public void MobThatCantFitStandsARankOut()
        {
            // stop radius 1.5: four mobs on one line can't get 2.7 apart within 25° each
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 90, radius: 1.5f), M(2, 90, radius: 1.5f), M(3, 90, radius: 1.5f), M(4, 90, radius: 1.5f) });
            Assert.Contains(s, x => x.SecondRank);
            foreach (var x in s)
                if (x.SecondRank)
                    Assert.Equal(3.0f, x.Radius, 3);
            for (int i = 0; i < s.Length; i++)
                for (int j = i + 1; j < s.Length; j++)
                    if (!s[i].SecondRank && !s[j].SecondRank)
                        Assert.True(Dist(s[i], s[j]) >= MeleeSpread.SPACING_MIN, $"{i} {j} {Dist(s[i], s[j])}");
        }

        [Fact]
        public void BigBodiesNeedMoreRoom()
        {
            Assert.Equal(MeleeSpread.SPACING, MeleeSpread.Spacing(0.5f, 0.5f));
            Assert.Equal(4.5f, MeleeSpread.Spacing(2.0f, 2.0f), 3);
        }

        [Fact]
        public void SolutionIsTheSameWhateverTheMembersOrder()
        {
            var a = MeleeSpread.Solve(0, 0, new[] { M(1, 85), M(2, 90), M(3, 96) });
            var b = MeleeSpread.Solve(0, 0, new[] { M(3, 96), M(1, 85), M(2, 90) });
            Assert.Equal(a[0].Theta, b[1].Theta, 4);
            Assert.Equal(a[1].Theta, b[2].Theta, 4);
            Assert.Equal(a[2].Theta, b[0].Theta, 4);
        }

        [Fact]
        public void BearingsAcrossMinusPiWrap()
        {
            var s = MeleeSpread.Solve(0, 0, new[] { M(1, 178), M(2, -178) });
            Assert.True(Dist(s[0], s[1]) >= MeleeSpread.SPACING_MIN, $"{Dist(s[0], s[1])}");
            Assert.InRange(MathF.Abs(Shift(s[0])), 0, 25.01f);
        }
    }
}
