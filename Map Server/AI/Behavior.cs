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
using Meteor.Map.Actors;
using Meteor.Map.Scripting;

namespace Meteor.Map.AI
{
    [Flags]
    enum Channels
    {
        None = 0,
        Move = 1,
        Face = 2,
        Target = 4,
        Act = 8,
        Sense = 16,
        Speak = 32,
        All = Move | Face | Target | Act | Sense | Speak,
    }

    static class Bands
    {
        public const int Ambient = 100, Role = 300, Combat = 400, Survival = 500, Mechanic = 700, Script = 850, Control = 950;
    }

    // One kind of conduct. The brain asks every behavior what it wants each tick and grants each
    // channel to the highest-priority behavior that wants it.
    abstract class Behavior
    {
        public string Kind { get; internal set; }
        public string Id { get; internal set; }
        public int Priority { get; set; }
        public ScriptParams Params { get; private set; } = ScriptParams.Empty;
        public bool Suspended { get; set; }
        public Channels Held { get; internal set; }
        internal long Order;
        internal long EndsAtMs;
        internal ScriptCallback Until;

        protected Brain brain;
        protected Character Actor => brain.Owner;
        protected SeededRandom Rng => brain.Rng;
        protected long Now => GameClock.NowMs;

        public abstract int DefaultPriority { get; }
        public abstract Channels DefaultChannels { get; }

        // Ticked even when it wants no channel (watchers such as Link).
        public virtual bool Watches => false;

        internal void Bind(Brain brain)
        {
            this.brain = brain;
        }

        public virtual void Configure(ScriptParams p)
        {
            Params = p ?? ScriptParams.Empty;
            if (Params.Has("priority"))
                Priority = Params.Int("priority");
        }

        public virtual Channels Wants() => DefaultChannels;
        public virtual void OnAdd() { }
        public abstract void Tick(Channels granted);
        public virtual void OnLose(Channels lost) { }
        public virtual void OnRemove() { }
        public virtual void OnEvent(ActorEvent e) { }

        protected void Finish(string reason = "done")
        {
            brain.Remove(Id, reason);
        }

        public virtual string Describe() => "";
    }
}
