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
using Meteor.Map.Actors;
using Meteor.Map.Content;

namespace Meteor.Map.AI
{
    enum ActorEventType
    {
        Spawned, Despawned, Died, Raised,
        Aggro, Engaged, Disengaged, TargetChanged,
        Damaged, Healed, HpCrossed,
        CastStarted, CastInterrupted, ActionDone, StatusGained, StatusLost,
        WaypointReached, PathFailed, EnteredRegion, LeftRegion,
        Talked, ItemGiven, Emoted,
        BehaviorEnded, Fled, Recovered,
        PhaseChanged, ObjectiveChanged, EncounterEnded, HazardResolved,
        Signal,
    }

    // Public fields: scripts read them by name.
    class ActorEvent
    {
        public ActorEventType Type;
        public Character Actor;
        public Character Other;
        public int Amount;
        public uint ActionId;
        public string Name;
        public object Data;
        public Encounter Encounter;
        public bool Handled;

        public string TypeName => Type.ToString();

        public ActorEvent(ActorEventType type, Character actor = null, Character other = null)
        {
            Type = type;
            Actor = actor;
            Other = other;
        }
    }

    // Events raised during a tick step queue here and drain at the end of the step, so a handler
    // never runs inside the engine code that raised the event.
    static class EventBus
    {
        private const int MaxDepth = 8;
        private static readonly Queue<ActorEvent> queue = new Queue<ActorEvent>();
        private static bool draining;
        private static readonly List<ActorEvent> recent = new List<ActorEvent>();
        private static long seq;

        public static long Sequence => seq;
        public static int Pending => queue.Count;

        public static void Raise(ActorEvent e)
        {
            if (e == null)
                return;
            queue.Enqueue(e);
        }

        public static void Raise(ActorEventType type, Character actor, Character other = null, int amount = 0, string name = null, object data = null)
        {
            Raise(new ActorEvent(type, actor, other) { Amount = amount, Name = name, Data = data });
        }

        public static void Drain()
        {
            if (draining)
                return;
            draining = true;
            try
            {
                for (int depth = 0; depth < MaxDepth && queue.Count > 0; depth++)
                {
                    int n = queue.Count;
                    for (int i = 0; i < n; i++)
                        Deliver(queue.Dequeue());
                }
                if (queue.Count > 0)
                {
                    Program.Log.Warn("Event bus: {0} events left after {1} passes; dropping them.", queue.Count, MaxDepth);
                    queue.Clear();
                }
            }
            finally
            {
                draining = false;
            }
        }

        // Behaviors, the actor's script, the owning content, then the zone script.
        private static void Deliver(ActorEvent e)
        {
            Remember(e);
            try
            {
                Brain brain = e.Actor?.Brain;
                brain?.Deliver(e);
                if (e.Actor?.content != null)
                    e.Actor.content.Deliver(e);
                else if (e.Encounter != null)
                    e.Encounter.Deliver(e);
                ContentManager.DeliverToZone(e);
            }
            catch (Exception ex)
            {
                Program.Log.Error("Event {0} for {1} failed: {2}", e.Type, e.Actor?.Id, ex);
            }
        }

        private static void Remember(ActorEvent e)
        {
            seq++;
            recent.Add(e);
            if (recent.Count > 512)
                recent.RemoveRange(0, recent.Count - 512);
        }

        public static List<object> Recent(long since)
        {
            var list = new List<object>();
            long first = seq - recent.Count + 1;
            for (int i = 0; i < recent.Count; i++)
            {
                long s = first + i;
                if (s <= since)
                    continue;
                var e = recent[i];
                list.Add(new { seq = s, type = e.Type.ToString(), actor = e.Actor?.Id, other = e.Other?.Id, e.Amount, e.Name, encounter = e.Encounter?.Id ?? e.Actor?.content?.Id });
            }
            return list;
        }

        public static void Clear()
        {
            queue.Clear();
            recent.Clear();
        }
    }
}
