using System;
using System.Linq;
using Meteor.Map.lua;
using Xunit;

namespace Meteor.Map.Tests
{
    // A fixed seed must replay every roll, in C# and in scripts, or a fight can't be repeated.
    [Collection("engines")]
    public sealed class DiceTests
    {
        private readonly LuaScript script;

        public DiceTests(EngineFixture engines)
        {
            script = engines.Engine.Load("./scripts/__tests/dice.lua");
            Assert.Null(script.LoadError);
        }

        private static double[] Doubles(Dice dice, int n) => Enumerable.Range(0, n).Select(_ => dice.NextDouble()).ToArray();

        private double[] Lua(string function, params object[] args) =>
            script.Call(function, args).Select(Convert.ToDouble).ToArray();

        [Fact]
        public void SameSeedSameRolls()
        {
            Assert.Equal(Doubles(new Dice(7), 1000), Doubles(new Dice(7), 1000));
        }

        [Fact]
        public void DifferentSeedDifferentRolls()
        {
            Assert.NotEqual(Doubles(new Dice(7), 16), Doubles(new Dice(8), 16));
        }

        [Fact]
        public void ReseedRestarts()
        {
            var dice = new Dice(42);
            var first = Doubles(dice, 32);
            dice.Reseed(42);
            Assert.Equal(first, Doubles(dice, 32));
            Assert.Equal(32, dice.Rolls);
        }

        [Fact]
        public void RangesMatchSystemRandom()
        {
            var dice = new Dice(3);
            for (int i = 0; i < 10000; i++)
            {
                double d = dice.NextDouble();
                Assert.InRange(d, 0.0, 0.9999999999999999);
                Assert.InRange(dice.Next(10), 0, 9);
                Assert.InRange(dice.Next(30, 60), 30, 59);
            }
            Assert.Equal(5, dice.Next(5, 5));
            Assert.Equal(0, dice.Next(0));
        }

        [Fact]
        public void EveryValueInRangeComesUp()
        {
            var dice = new Dice(11);
            var seen = Enumerable.Range(0, 2000).Select(_ => dice.Next(1, 7)).Distinct().OrderBy(v => v);
            Assert.Equal(new[] { 1, 2, 3, 4, 5, 6 }, seen);
        }

        [Fact]
        public void ScriptRollsFollowTheServerSeed()
        {
            Dice.Shared.Reseed(99);
            var first = Lua("unitRolls", 64);
            Dice.Shared.Reseed(99);
            Assert.Equal(first, Lua("unitRolls", 64));
            Assert.Equal(Doubles(new Dice(99), 64), first);
        }

        [Fact]
        public void ScriptRangesAreInclusiveIntegers()
        {
            Dice.Shared.Reseed(5);
            var rolls = Lua("rangedRolls", 5, 7, 3000);
            Assert.All(rolls, r => Assert.True(r == Math.Floor(r) && r >= 5 && r <= 7, $"roll {r}"));
            Assert.Equal(new[] { 5.0, 6.0, 7.0 }, rolls.Distinct().OrderBy(v => v));
        }

        [Fact]
        public void ScriptCannotReseed()
        {
            Dice.Shared.Reseed(21);
            double fromScript = Lua("reseed")[0];
            Assert.Equal(new Dice(21).NextDouble(), fromScript);
        }
    }
}
