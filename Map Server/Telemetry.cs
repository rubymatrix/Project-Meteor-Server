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
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading;

namespace Meteor.Map
{
    class TelemetryEvent
    {
        public long Seq;
        public DateTime Time;
        public string Kind;
        public uint Actor;
        public uint Target;
        // Seq of the event that caused this one, 0 if none.
        public long Cause;
        public Dictionary<string, object> Data;

        public object this[string key] => Data != null && Data.TryGetValue(key, out var v) ? v : null;

        public double Number(string key) => Convert.ToDouble(this[key]);

        public string ToJson()
        {
            return JsonSerializer.Serialize(new
            {
                seq = Seq,
                t = (Time.Kind == DateTimeKind.Utc ? new DateTimeOffset(Time) : new DateTimeOffset(Time.ToUniversalTime())).ToUnixTimeMilliseconds(),
                kind = Kind,
                actor = Actor,
                target = Target,
                cause = Cause,
                data = Data,
            });
        }

        public override string ToString() => ToJson();
    }

    interface ITelemetrySink
    {
        void Write(TelemetryEvent e);
    }

    // Events from the places battle decides an outcome. Off until a sink is attached. Each caller
    // checks On first, so it costs almost nothing when off.
    static class Telemetry
    {
        private static ITelemetrySink[] sinks = Array.Empty<ITelemetrySink>();
        private static readonly object Gate = new object();
        private static long seq;

        [ThreadStatic] private static long cause;
        [ThreadStatic] private static List<KeyValuePair<string, object>> steps;

        public static bool On => sinks.Length != 0;

        public static IDisposable Attach(ITelemetrySink sink)
        {
            lock (Gate)
                sinks = sinks.Append(sink).ToArray();
            return new Detacher(sink);
        }

        public static void Detach(ITelemetrySink sink)
        {
            lock (Gate)
                sinks = sinks.Where(s => s != sink).ToArray();
        }

        public static long Reserve() => Interlocked.Increment(ref seq);

        public static long Emit(string kind, uint actor, uint target, params (string, object)[] data)
        {
            return Emit(Reserve(), kind, actor, target, data);
        }

        // Writes an event under a seq taken earlier with Reserve, so an event can be the cause of
        // the events it leads to and still carry their outcome.
        public static long Emit(long id, string kind, uint actor, uint target, params (string, object)[] data)
        {
            var current = sinks;
            if (current.Length == 0)
                return 0;
            var e = new TelemetryEvent
            {
                Seq = id,
                Time = GameClock.Now,
                Kind = kind,
                Actor = actor,
                Target = target,
                Cause = cause == id ? 0 : cause,
                Data = new Dictionary<string, object>(data.Length),
            };
            foreach (var (k, v) in data)
                e.Data[k] = v;
            foreach (var s in current)
                s.Write(e);
            return id;
        }

        // Events emitted inside the scope name id as their cause.
        public static CauseScope Because(long id) => new CauseScope(id);

        public readonly struct CauseScope : IDisposable
        {
            private readonly long previous;

            public CauseScope(long id)
            {
                previous = cause;
                if (id != 0)
                    cause = id;
            }

            public void Dispose() => cause = previous;
        }

        // A named value from a formula (Lua trace()). The next action.result carries them.
        public static void Step(string name, object value)
        {
            if (!On)
                return;
            steps ??= new List<KeyValuePair<string, object>>();
            // Steps from a formula no action used would otherwise pile up.
            if (steps.Count >= 64)
                steps.Clear();
            steps.Add(new KeyValuePair<string, object>(name, value));
        }

        public static Dictionary<string, object> TakeSteps()
        {
            if (steps == null || steps.Count == 0)
                return null;
            var r = new Dictionary<string, object>();
            foreach (var kv in steps)
                r[kv.Key] = kv.Value;
            steps.Clear();
            return r;
        }

        private sealed class Detacher : IDisposable
        {
            private readonly ITelemetrySink sink;
            public Detacher(ITelemetrySink sink) { this.sink = sink; }
            public void Dispose() => Detach(sink);
        }
    }

    class TelemetryRecorder : ITelemetrySink
    {
        public readonly List<TelemetryEvent> Events = new List<TelemetryEvent>();

        public void Write(TelemetryEvent e)
        {
            lock (Events)
                Events.Add(e);
        }

        // Events of a kind, or of every kind under a prefix ending in '.' ("status.").
        public IEnumerable<TelemetryEvent> Of(string kind)
        {
            lock (Events)
                return Events.Where(e => kind.EndsWith(".") ? e.Kind.StartsWith(kind, StringComparison.Ordinal) : e.Kind == kind).ToList();
        }

        public TelemetryEvent Get(long seq)
        {
            lock (Events)
                return Events.FirstOrDefault(e => e.Seq == seq);
        }
    }

    // The most recent events, kept in memory for the admin API to page through.
    class TelemetryRing : ITelemetrySink
    {
        private readonly TelemetryEvent[] ring;
        private long count;

        public TelemetryRing(int capacity = 50000)
        {
            ring = new TelemetryEvent[capacity];
        }

        public void Write(TelemetryEvent e)
        {
            lock (ring)
            {
                ring[count % ring.Length] = e;
                count++;
                Monitor.PulseAll(ring);
            }
        }

        public List<TelemetryEvent> Since(long seq, ICollection<string> kinds = null, int waitMs = 0)
        {
            lock (ring)
            {
                var r = Collect(seq, kinds);
                if (r.Count == 0 && waitMs > 0)
                {
                    Monitor.Wait(ring, waitMs);
                    r = Collect(seq, kinds);
                }
                return r;
            }
        }

        private List<TelemetryEvent> Collect(long seq, ICollection<string> kinds)
        {
            var r = new List<TelemetryEvent>();
            long first = Math.Max(0, count - ring.Length);
            for (long i = first; i < count; i++)
            {
                var e = ring[i % ring.Length];
                if (e.Seq > seq && (kinds == null || kinds.Count == 0 || kinds.Contains(e.Kind)))
                    r.Add(e);
            }
            return r;
        }
    }
}
