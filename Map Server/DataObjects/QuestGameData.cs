using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Meteor.Map.DataObjects
{
    class QuestGameData
    {
        public uint Id { get; }
        public string ClassName { get; }
        public string Name { get; }
        public uint PrerequisiteQuest { get; }
        public int MinLevel { get; }
        public int MinGCRank { get; set; }
        // Client quest sheet template rows: placeholders and talk-only entries. Never offered.
        public bool IsTemplate { get; }

        // ClassScope: 0 all, 1 Disciples of War/Magic, 2 Disciples of the Land, 3 Disciples of the Hand.
        public byte ClassScope { get; set; }
        public byte RequiredClass { get; set; }
        public byte SecondClass { get; set; }
        public byte SecondClassLevel { get; set; }
        public bool RequireJob { get; set; }
        public byte GrandCompany { get; set; }
        // Any one of these completed unlocks the quest; when null, PrerequisiteQuest alone applies.
        public List<uint> Prerequisites { get; set; }
        // A quest without a script is never offered: starting it would fail in onStateChange.
        public bool HasScript { get; set; }

        public QuestGameData(uint id, string className, string name, uint prereq, int minLv, int minGcRank, bool isTemplate = false)
        {
            Id = id;
            ClassName = className;
            Name = name;
            PrerequisiteQuest = prereq;
            MinLevel = minLv;
            MinGCRank = minGcRank;
            IsTemplate = isTemplate;
        }
    }
}
