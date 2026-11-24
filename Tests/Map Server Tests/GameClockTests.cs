using System;
using Xunit;
using Meteor.Common;

namespace Meteor.Map.Tests
{
    [Collection("engines")]
    public sealed class GameClockTests
    {
        [Fact]
        public void ManualClockDrivesGameTime()
        {
            var clock = new ManualClock(new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc));
            GameClock.Use(() => clock.Now);
            try
            {
                Assert.Equal(clock.Now, GameClock.Now);
                clock.Advance(3.0);
                Assert.Equal(new DateTime(2026, 1, 1, 12, 0, 3, DateTimeKind.Utc), GameClock.Now);
                Assert.Equal(1767268803u, Common.Utils.UnixTimeStampUTC(GameClock.Now));
            }
            finally
            {
                GameClock.Use(null);
            }
        }

        [Fact]
        public void DefaultsToWallClock()
        {
            var before = DateTime.Now;
            var now = GameClock.Now;
            Assert.InRange(now, before, DateTime.Now);
        }
    }
}
