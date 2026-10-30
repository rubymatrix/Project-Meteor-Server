using Meteor.Map.lua;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Meteor.Map.Actors.QuestNS
{
    class QuestState
    {
        public enum QuestFlag { None = 0, Map = 1, Plate = 2 }

        public class QuestENpc
        {
            public readonly uint actorClassId;
            public byte questFlagType { set; get; }
            public bool isSpawned { set; get; }
            public bool isTalkEnabled { set; get; }
            public bool isEmoteEnabled { set; get; }
            public bool isPushEnabled { set; get; }

            public QuestENpc(uint actorClassId, byte questFlagType, bool isSpawned, bool isTalkEnabled, bool isEmoteEnabled, bool isPushEnabled)
            {
                this.actorClassId = actorClassId;
                this.questFlagType = questFlagType;
                this.isSpawned = isSpawned;
                this.isTalkEnabled = isTalkEnabled;
                this.isEmoteEnabled = isEmoteEnabled;
                this.isPushEnabled = isPushEnabled;
            }

            public bool IsChanged(byte flagType, bool isTalkEnabled, bool isPushEnabled, bool isEmoteEnabled, bool isSpawned)
            {
                return flagType != this.questFlagType
                    || isTalkEnabled != this.isTalkEnabled
                    || isPushEnabled != this.isPushEnabled
                    || isEmoteEnabled != this.isEmoteEnabled
                    || isSpawned != this.isSpawned;
            }

            public void Update(byte flagType, bool isTalkEnabled, bool isPushEnabled, bool isEmoteEnabled, bool isSpawned)
            {
                this.questFlagType = flagType;
                this.isSpawned = isSpawned;
                this.isTalkEnabled = isTalkEnabled;
                this.isEmoteEnabled = isEmoteEnabled;
                this.isPushEnabled = isPushEnabled;
            }
        }

        private readonly Player Owner;
        private readonly Quest Parent;
        private Dictionary<uint, QuestENpc> CurrentENPCs = new Dictionary<uint, QuestENpc>();
        private Dictionary<uint, QuestENpc> OldENPCs = new Dictionary<uint, QuestENpc>();
        private bool inStateUpdate;

        public QuestState(Player owner, Quest parent)
        {
            Owner = owner;
            Parent = parent;
        }

        public void AddENpc(uint classId, byte flagType = 0, bool isTalkEnabled = true, bool isPushEnabled = false, bool isEmoteEnabled = false, bool isSpawned = false)
        {
            QuestENpc instanceUpdated = null;
            QuestENpc before = GetENpc(classId) ?? (OldENPCs != null && OldENPCs.ContainsKey(classId) ? OldENPCs[classId] : null);
            bool wasSpawned = before != null && before.isSpawned;

            if (OldENPCs != null && OldENPCs.ContainsKey(classId))
            {
                if (OldENPCs[classId].IsChanged(flagType, isTalkEnabled, isPushEnabled, isEmoteEnabled, isSpawned))
                {
                    OldENPCs[classId].Update(flagType, isTalkEnabled, isPushEnabled, isEmoteEnabled, isSpawned);
                    instanceUpdated = OldENPCs[classId];
                }

                // Replace dupes
                if (CurrentENPCs.ContainsKey(classId))
                    CurrentENPCs.Remove(classId);

                CurrentENPCs.Add(classId, OldENPCs[classId]);
                OldENPCs.Remove(classId);
            }
            else if (CurrentENPCs.ContainsKey(classId))
            {
                // Set twice in one update, when a script's sequence checks overlap: the later call wins.
                if (CurrentENPCs[classId].IsChanged(flagType, isTalkEnabled, isPushEnabled, isEmoteEnabled, isSpawned))
                {
                    CurrentENPCs[classId].Update(flagType, isTalkEnabled, isPushEnabled, isEmoteEnabled, isSpawned);
                    instanceUpdated = CurrentENPCs[classId];
                }
            }
            else
            {
                instanceUpdated = new QuestENpc(classId, flagType, isSpawned, isTalkEnabled, isEmoteEnabled, isPushEnabled);
                CurrentENPCs.Add(classId, instanceUpdated);
            }

            if (instanceUpdated != null)
                Owner.playerSession.UpdateQuestNpcInInstance(instanceUpdated);

            // Called outside onStateChange (from onTalk etc.): spawn/remove the story actor now.
            if (!inStateUpdate && wasSpawned != isSpawned)
                Owner.RefreshQuestNpcs();
        }

        public QuestENpc GetENpc(uint classId)
        {
            if (CurrentENPCs.ContainsKey(classId))
                return CurrentENPCs[classId];
            return null;
        }

        public bool HasENpc(uint classId)
        {
            return CurrentENPCs.ContainsKey(classId);
        }

        public void UpdateState()
        {
            ushort currentSeq = Parent.GetSequence();
            OldENPCs = CurrentENPCs;
            CurrentENPCs = new Dictionary<uint, QuestENpc>();
            inStateUpdate = true;
            try
            {
                LuaEngine.GetInstance().CallLuaFunctionForReturn(Owner, Parent, "onStateChange", false, currentSeq);
            }
            finally
            {
                inStateUpdate = false;
            }
            foreach (var enpc in OldENPCs)
                Owner.playerSession.UpdateQuestNpcInInstance(enpc.Value, true);
            OldENPCs = null;
            Owner.RefreshQuestNpcs();
        }

        public void DeleteState()
        {
            foreach (var enpc in CurrentENPCs)
                Owner.playerSession.UpdateQuestNpcInInstance(enpc.Value, true);
            CurrentENPCs.Clear();
            Owner.RefreshQuestNpcs();
        }
    }
}
