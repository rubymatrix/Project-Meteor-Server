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

namespace Meteor.Map.actors.director.Work
{
    // The director's work table, sync tag "info" (target "work/info"). The client's Survive and Round
    // classes draw a 5th objective row from it while guildleveWork.startTime > 0: the defense time left
    // (surviveStop freezes it, surviveTime 0 shows cleared) or roundNumber / roundNumberMax.
    class GuildleveInfoWork
    {
        public short surviveTime = 0;       // int16, defense length in seconds
        public short surviveStartTime = 0;  // int16, seconds after guildleveWork.startTime
        public bool surviveStop = false;
        public sbyte roundNumber = 0;
        public sbyte roundNumberMax = 0;
    }
}
