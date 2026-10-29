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

namespace Meteor.Map.AI
{
    enum Relation : byte
    {
        Hostile,
        Neutral,     // fights back once attacked
        Friendly,    // heals, buffs and assists
        Ignore,
    }

    // Every character has one faction; a global table says how factions treat each other.
    // Content may override relations for the actors it owns.
    static class Factions
    {
        public const int Player = 0, PlayerAlly = 1, Monster = 2, Neutral = 3;

        private static readonly List<string> names = new List<string>();
        private static readonly Dictionary<string, int> ids = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        private static readonly Dictionary<(int, int), Relation> relations = new Dictionary<(int, int), Relation>();

        static Factions()
        {
            Reset();
        }

        public static void Reset()
        {
            names.Clear();
            ids.Clear();
            relations.Clear();
            Define("Player");
            Define("PlayerAlly");
            Define("Monster");
            Define("Neutral");
            Relate(Player, PlayerAlly, Relation.Friendly);
            Relate(Monster, Player, Relation.Hostile);
            Relate(Monster, PlayerAlly, Relation.Hostile);
            Relate(Neutral, Player, Relation.Ignore);
            Relate(Neutral, PlayerAlly, Relation.Ignore);
            Relate(Neutral, Monster, Relation.Ignore);
        }

        public static int Define(string name)
        {
            if (ids.TryGetValue(name, out int id))
                return id;
            id = names.Count;
            names.Add(name);
            ids[name] = id;
            return id;
        }

        public static int Id(string name)
        {
            if (string.IsNullOrEmpty(name))
                return -1;
            return ids.TryGetValue(name, out int id) ? id : -1;
        }

        public static string Name(int id) => id >= 0 && id < names.Count ? names[id] : "?";

        public static void Relate(int a, int b, Relation r)
        {
            relations[(a, b)] = r;
            relations[(b, a)] = r;
        }

        public static void Relate(string a, string b, string relation)
        {
            Relate(Define(a), Define(b), Parse(relation));
        }

        public static Relation Parse(string relation)
        {
            switch ((relation ?? "").ToLowerInvariant())
            {
                case "hostile": return Relation.Hostile;
                case "neutral": return Relation.Neutral;
                case "friendly": return Relation.Friendly;
                default: return Relation.Ignore;
            }
        }

        // Same faction is always friendly. Pairs nobody related are neutral.
        public static Relation Between(int a, int b)
        {
            if (a == b)
                return Relation.Friendly;
            return relations.TryGetValue((a, b), out var r) ? r : Relation.Neutral;
        }

        public static Relation Between(Character a, Character b)
        {
            if (a == null || b == null)
                return Relation.Ignore;
            if (a == b)
                return Relation.Friendly;
            var over = a.content?.RelationOverride(a.factionId, b.factionId) ?? b.content?.RelationOverride(a.factionId, b.factionId);
            return over ?? Between(a.factionId, b.factionId);
        }

        public static bool IsHostile(Character a, Character b) => Between(a, b) == Relation.Hostile;

        public static bool IsFriendly(Character a, Character b) => Between(a, b) == Relation.Friendly;

        // May attack: hostile, or neutral once the target has hate on us or we on it.
        public static bool CanAttack(Character a, Character b)
        {
            var r = Between(a, b);
            if (r == Relation.Hostile)
                return true;
            if (r == Relation.Neutral)
                return (a.hateContainer?.HasHateForTarget(b) ?? false) || (b.hateContainer?.HasHateForTarget(a) ?? false);
            return false;
        }
    }
}
