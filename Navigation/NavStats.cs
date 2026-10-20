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
using System.Diagnostics;
using System.Text;
using System.Threading;

namespace Meteor.Navigation
{
    public enum NavOp { Project, PlanRoute, Advance, Walk, CanSee, RandomPoint, Reachable, Displace }

    /// <summary>Per-world query counters: calls, time (µs histogram), results by reason. Lock-free.</summary>
    public sealed class NavStats
    {
        /// <summary>Upper bounds (µs) of the histogram buckets; the last bucket is everything above.</summary>
        public static readonly double[] BucketLimitsUs = { 10, 50, 100, 500, 1000, 5000, 20000 };
        private static readonly int ReasonCount = Enum.GetValues(typeof(NavReason)).Length;
        private static readonly int OpCount = Enum.GetValues(typeof(NavOp)).Length;

        public sealed class Counters
        {
            public long Calls;
            public long Ticks;
            public long MaxTicks;
            public readonly long[] Reasons = new long[ReasonCount];
            public readonly long[] Buckets = new long[BucketLimitsUs.Length + 1];

            public double TotalUs => ToMicroseconds(Interlocked.Read(ref Ticks));
            public double MaxUs => ToMicroseconds(Interlocked.Read(ref MaxTicks));
            public double MeanUs => Calls == 0 ? 0 : TotalUs / Calls;
            public long Failures
            {
                get
                {
                    long n = 0;
                    for (int i = 0; i < Reasons.Length; i++)
                        if (i != (int)NavReason.Ok && i != (int)NavReason.Partial)
                            n += Interlocked.Read(ref Reasons[i]);
                    return n;
                }
            }
        }

        private Counters[] ops = NewOps();
        public DateTime Since { get; private set; } = DateTime.Now;

        private static Counters[] NewOps()
        {
            var a = new Counters[OpCount];
            for (int i = 0; i < a.Length; i++)
                a[i] = new Counters();
            return a;
        }

        public Counters this[NavOp op] => Volatile.Read(ref ops)[(int)op];

        public static long Now() => Stopwatch.GetTimestamp();

        public static double ToMicroseconds(long ticks) => ticks * 1_000_000.0 / Stopwatch.Frequency;

        public void Record(NavOp op, NavReason reason, long startTimestamp)
        {
            long elapsed = Stopwatch.GetTimestamp() - startTimestamp;
            var c = this[op];
            Interlocked.Increment(ref c.Calls);
            Interlocked.Add(ref c.Ticks, elapsed);
            Interlocked.Increment(ref c.Reasons[(int)reason]);
            double us = ToMicroseconds(elapsed);
            int b = 0;
            while (b < BucketLimitsUs.Length && us > BucketLimitsUs[b])
                b++;
            Interlocked.Increment(ref c.Buckets[b]);
            long max;
            while (elapsed > (max = Interlocked.Read(ref c.MaxTicks)) && Interlocked.CompareExchange(ref c.MaxTicks, elapsed, max) != max) { }
        }

        public void Reset()
        {
            Volatile.Write(ref ops, NewOps());
            Since = DateTime.Now;
        }

        public string Summary()
        {
            var sb = new StringBuilder();
            foreach (NavOp op in Enum.GetValues(typeof(NavOp)))
            {
                var c = this[op];
                if (c.Calls == 0)
                    continue;
                sb.Append($"{op}: {c.Calls} calls, mean {c.MeanUs:F1} µs, max {c.MaxUs:F0} µs");
                for (int r = 0; r < c.Reasons.Length; r++)
                    if (r != 0 && c.Reasons[r] > 0)
                        sb.Append($", {(NavReason)r} {c.Reasons[r]}");
                sb.AppendLine();
            }
            return sb.ToString();
        }
    }
}
