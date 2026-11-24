/*
===========================================================================
Copyright (C) 2015-2019 Project Meteor Dev Team

This file is part of Project Meteor Server.

Project Meteor Server is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Project Meteor Server is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with Project Meteor Server. If not, see <https:www.gnu.org/licenses/>.
===========================================================================
*/

using System;
using System.Security.Cryptography;

namespace Meteor.Common
{
    // Every random roll the game makes. A fixed seed makes tests repeat exactly. A seed of 0
    // picks a random one from the OS, so live rolls can't be guessed from the start time.
    public class Dice
    {
        private const ulong Multiplier = 6364136223846793005UL;
        private const ulong Increment = 1442695040888963407UL;

        public static readonly Dice Shared = new Dice(0);

        private readonly object sync = new object();
        private ulong state;

        public ulong Seed { get; private set; }
        public long Rolls { get; private set; }

        public Dice(ulong seed)
        {
            Reseed(seed);
        }

        public void Reseed(ulong seed)
        {
            lock (sync)
            {
                if (seed == 0)
                    seed = BitConverter.ToUInt64(RandomNumberGenerator.GetBytes(8)) | 1;
                Seed = seed;
                Rolls = 0;
                state = 0;
                Step();
                state += seed;
                Step();
            }
        }

        private uint Step()
        {
            ulong old = state;
            state = old * Multiplier + Increment;
            uint xorShifted = (uint)(((old >> 18) ^ old) >> 27);
            int rot = (int)(old >> 59);
            return (xorShifted >> rot) | (xorShifted << ((-rot) & 31));
        }

        public uint NextUInt()
        {
            lock (sync)
            {
                Rolls++;
                return Step();
            }
        }

        // [0, 1), at full double precision.
        public double NextDouble()
        {
            lock (sync)
            {
                Rolls++;
                ulong hi = Step() >> 5, lo = Step() >> 6;
                return (hi * 67108864.0 + lo) / 9007199254740992.0;
            }
        }

        // [0, max), like System.Random.Next(int).
        public int Next(int max)
        {
            if (max <= 0)
                return 0;
            return (int)(NextDouble() * max);
        }

        // [min, max), like System.Random.Next(int, int).
        public int Next(int min, int max)
        {
            if (max <= min)
                return min;
            return min + (int)(NextDouble() * ((long)max - min));
        }
    }
}
