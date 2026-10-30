using System;
using System.Collections.Generic;

namespace Meteor.Map.Actors.QuestNS
{
    // One server_eventnpc_quest_gated row: the story actor exists for a player whose quest is held at a
    // sequence in [minSequence, maxSequence] (the default range admits every sequence).
    public class QuestGate
    {
        public readonly uint questId;
        public readonly ushort minSequence;
        public readonly ushort maxSequence;

        public QuestGate(uint questId, ushort minSequence = 0, ushort maxSequence = ushort.MaxValue)
        {
            this.questId = questId;
            this.minSequence = minSequence;
            this.maxSequence = maxSequence;
        }

        public bool Admits(ushort sequence)
        {
            return sequence >= minSequence && sequence <= maxSequence;
        }
    }

    // Picks which held quest a talk/push/emote on an ENPC goes to when several quests declare its class.
    // The quest that owns the spawn wins: a quest gate on the spawn, or the spawn's uniqueId prefix
    // ("gla306_stands_trig" belongs to Gla306). Next, a quest that enabled this kind of event on the class.
    // Ties keep the incoming order.
    public static class QuestNpcRouting
    {
        // Event types as the client sends them (PopulaceStandard): 1 talk, 2 push, 3 emote.
        public const int EVENT_ANY = -1, EVENT_TALK = 1, EVENT_PUSH = 2, EVENT_EMOTE = 3;

        public const int SCORE_GATE = 4, SCORE_NAME = 2, SCORE_KIND = 1;

        public static bool OwnsByName(string questName, string uniqueId)
        {
            if (string.IsNullOrEmpty(questName) || string.IsNullOrEmpty(uniqueId))
                return false;
            return uniqueId.StartsWith(questName + "_", StringComparison.OrdinalIgnoreCase);
        }

        public static int Score(bool ownsByGate, bool ownsByName, bool kindEnabled)
        {
            return (ownsByGate ? SCORE_GATE : 0) + (ownsByName ? SCORE_NAME : 0) + (kindEnabled ? SCORE_KIND : 0);
        }

        // Stable sort, highest score first.
        public static List<T> Order<T>(IList<T> items, Func<T, int> score)
        {
            var indexed = new List<KeyValuePair<int, T>>(items.Count);
            for (int i = 0; i < items.Count; i++)
                indexed.Add(new KeyValuePair<int, T>(i, items[i]));
            indexed.Sort((a, b) =>
            {
                int byScore = score(b.Value).CompareTo(score(a.Value));
                return byScore != 0 ? byScore : a.Key.CompareTo(b.Key);
            });
            var result = new List<T>(items.Count);
            foreach (var pair in indexed)
                result.Add(pair.Value);
            return result;
        }
    }
}
