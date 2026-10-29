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
using System.Threading;

namespace Meteor.Map.Scripting
{
    // Logged with the content that owns it so a run can be replayed.
    class SeededRandom
    {
        private static int nextSeed = Environment.TickCount;
        private readonly Random rng;

        public int Seed { get; }

        public SeededRandom(int? seed = null)
        {
            Seed = seed ?? Interlocked.Increment(ref nextSeed);
            rng = new Random(Seed);
        }

        public double Next() => rng.NextDouble();

        public double Range(double min, double max) => min + (max - min) * rng.NextDouble();

        public int Int(int min, int maxInclusive) => maxInclusive <= min ? min : rng.Next(min, maxInclusive + 1);

        public bool Chance(double p) => rng.NextDouble() < p;
    }
}
