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

namespace Meteor.Map.Scripting
{
    // Game time for AI and content code. The zone loop advances it from the wall clock; tests
    // switch it to manual and step it.
    static class GameClock
    {
        private static readonly DateTime Epoch = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        public static bool Manual { get; private set; }
        public static long NowMs { get; private set; } = WallMs();
        public static DateTime Now => Epoch.AddMilliseconds(NowMs);
        public static double NowSeconds => NowMs / 1000.0;

        public static void Advance()
        {
            if (!Manual)
                NowMs = Math.Max(NowMs, WallMs());
        }

        public static void SetManual(long startMs = 0)
        {
            Manual = true;
            NowMs = startMs;
        }

        public static void SetAutomatic()
        {
            Manual = false;
            NowMs = WallMs();
        }

        public static void Step(long ms)
        {
            NowMs += Math.Max(0, ms);
        }

        private static long WallMs() => (long)(DateTime.UtcNow - Epoch).TotalMilliseconds;
    }
}
