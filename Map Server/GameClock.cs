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

namespace Meteor.Map
{
    // The time game logic runs on. Live it is the wall clock; tests set a manual clock and step it.
    static class GameClock
    {
        private static Func<DateTime> source = () => DateTime.Now;

        public static DateTime Now => source();

        public static void Use(Func<DateTime> clock)
        {
            source = clock ?? (() => DateTime.Now);
        }
    }

    class ManualClock
    {
        public DateTime Now { get; private set; }

        public ManualClock(DateTime start)
        {
            Now = start;
        }

        public void Advance(TimeSpan by)
        {
            Now += by;
        }

        public void Advance(double seconds)
        {
            Now = Now.AddSeconds(seconds);
        }
    }
}
