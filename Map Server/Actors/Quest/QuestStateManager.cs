using Meteor.Common;
using Meteor.Map.DataObjects;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Meteor.Map.Actors.QuestNS
{
    class QuestStateManager
    {
        private const int SCENARIO_START = 110001;
        private const int SCENARIO_MAX = 2048;

        private readonly Player player;
        private readonly Bitstream CompletedQuestsBitfield = new Bitstream(SCENARIO_MAX);
        private readonly Bitstream AvailableQuestsBitfield = new Bitstream(SCENARIO_MAX);
        // Quests this character may be offered right now (level/class/GC/prerequisite gates);
        // rebuilt by RecomputeEligible whenever one of the inputs changes.
        private readonly Bitstream EligibleBitfield = new Bitstream(SCENARIO_MAX);

        private List<Quest> ActiveQuests = new List<Quest>();
        private List<Quest> UpdatableQuests = new List<Quest>();
        private Dictionary<uint, QuestState> QuestStateTable = new Dictionary<uint, QuestState>();

        public QuestStateManager(Player player)
        {
            this.player = player;
        }

        public void Init(Quest[] journalQuests, bool[] completedQuests)
        {
            // Preload any quests that the player loaded
            if (journalQuests != null)
            {
                foreach (var quest in journalQuests)
                {
                    if (quest != null)
                    {
                        ActiveQuests.Add(quest);
                        AvailableQuestsBitfield.Set(quest.GetQuestId() - SCENARIO_START);
                    }
                }
            }                

            CompletedQuestsBitfield.SetTo(completedQuests);
            ComputeAvailable();
        }

        // Level, class or job changed: the level gate uses the active class/job.
        public void UpdateLevel(int level)
        {
            ComputeAvailable();
        }

        public void UpdateQuestCompleted(Quest quest)
        {
            CompletedQuestsBitfield.Set(quest.GetQuestId() - SCENARIO_START);
            ComputeAvailable();
        }

        public void UpdateQuestAbandoned()
        {
            ComputeAvailable();
        }

        // Offer rules: the quest level is checked against the active class or job, not the highest
        // level; the class scope must match; class quests need that class, job quests the base class
        // (and second class, then the job); GC quests need that company and rank; any one listed
        // prerequisite must be complete. Templates and quests without a script are never offered.
        public bool IsEligible(QuestGameData q)
        {
            if (q.IsTemplate || q.MinLevel <= 0 || !q.HasScript)
                return false;

            byte cls = (byte)player.GetClass();
            if (player.GetLevel() < q.MinLevel)
                return false;

            switch (q.ClassScope)
            {
                case 1: if (!IsWarOrMagic(cls)) return false; break;
                case 2: if (cls < Player.CLASSID_MIN || cls > Player.CLASSID_FSH) return false; break;
                case 3: if (cls < Player.CLASSID_CRP || cls > Player.CLASSID_CUL) return false; break;
            }

            if (q.RequiredClass != 0 && cls != q.RequiredClass)
                return false;
            if (q.SecondClass != 0 && player.charaWork.battleSave.skillLevel[q.SecondClass - 1] < q.SecondClassLevel)
                return false;
            if (q.RequireJob && player.currentJob != Player.ConvertClassIdToJobId(q.RequiredClass))
                return false;

            if (q.GrandCompany != 0)
            {
                // The rank-0 company quests come before joining, so the unaffiliated get them too.
                if (player.gcCurrent != q.GrandCompany && !(q.MinGCRank == 0 && player.gcCurrent == 0))
                    return false;
                byte rank = q.GrandCompany == 1 ? player.gcRankLimsa : q.GrandCompany == 2 ? player.gcRankGridania : player.gcRankUldah;
                if (rank < q.MinGCRank)
                    return false;
            }

            if (q.Prerequisites != null)
            {
                bool any = false;
                foreach (uint pre in q.Prerequisites)
                {
                    if (IsQuestComplete(pre))
                    {
                        any = true;
                        break;
                    }
                }
                if (!any)
                    return false;
            }
            else if (q.PrerequisiteQuest != 0 && !IsQuestComplete(q.PrerequisiteQuest))
                return false;

            return true;
        }

        private static bool IsWarOrMagic(byte cls)
        {
            return cls == Player.CLASSID_PUG || cls == Player.CLASSID_GLA || cls == Player.CLASSID_MRD ||
                   cls == Player.CLASSID_ARC || cls == Player.CLASSID_LNC ||
                   cls == Player.CLASSID_THM || cls == Player.CLASSID_CNJ;
        }

        private void RecomputeEligible()
        {
            foreach (QuestGameData q in Server.GetAllQuestGamedata())
            {
                int index = (int)q.Id - SCENARIO_START;
                if (index < 0 || index >= SCENARIO_MAX)
                    continue;
                if (IsEligible(q))
                    EligibleBitfield.Set(index);
                else
                    EligibleBitfield.Clear(index);
            }
        }

        private void ComputeAvailable()
        {
            RecomputeEligible();
            Bitstream result = new Bitstream(SCENARIO_MAX);
            result.NOTOR(CompletedQuestsBitfield);
            result.AND(EligibleBitfield);

            Bitstream difference = AvailableQuestsBitfield.Copy();
            difference.XOR(result);
            byte[] diffBytes = difference.GetBytes();

            for (int i = 0; i < diffBytes.Length; i++)
            {
                if (diffBytes[i] == 0)
                    continue;
                for (int shift = 0; shift < 8; shift++)
                {
                    if ((diffBytes[i] >> shift & 1) == 1)
                    {
                        int index = i * 8 + shift;
                        Quest quest = (Quest)Server.GetStaticActors(0xA0F00000 | (SCENARIO_START + (uint)index));
                        if (!AvailableQuestsBitfield.Get(index))
                            AddActiveQuest(quest);
                        else
                            RemoveActiveQuest(quest);
                    }
                }
            }

            AvailableQuestsBitfield.SetTo(result);
        }

        public void ForceAddActiveQuest(Quest questInstance)
        {
            ActiveQuests.Add(questInstance);
            QuestStateTable.Add(questInstance.Id, questInstance.GetQuestState());
        }

        private void AddActiveQuest(Quest staticQuest)
        {
            Quest instance = new Quest(player, staticQuest);
            ActiveQuests.Add(instance);
            QuestStateTable.Add(staticQuest.Id, instance.GetQuestState());
        }

        private void RemoveActiveQuest(Quest staticQuest)
        {
            // Do not remove quests in the player's journal
            if (player.HasQuest(staticQuest.GetQuestId()))
                return;

            ActiveQuests.Remove(staticQuest);
            UpdatableQuests.Remove(staticQuest);

            if (QuestStateTable.ContainsKey(staticQuest.Id))
            {
                QuestStateTable[staticQuest.Id].DeleteState();
                QuestStateTable.Remove(staticQuest.Id);
            }
        }

        public void ForceQuestStateUpdate()
        {
            ComputeAvailable();
        }

        public Quest GetActiveQuest(uint id)
        {
            return ActiveQuests.Find(quest => quest.GetQuestId() == id);
        }

        public Quest[] GetQuestsForNpc(Npc npc, bool isPrivateArea)
        {
            return ActiveQuests.FindAll(quest => quest.IsQuestENPC(player, npc)).ToArray();
        }

        public byte[] GetCompletionSliceBytes(ushort from, ushort to)
        {
            return CompletedQuestsBitfield.GetSlice(from, to); 
        }

        public Bitstream GetCompletedQuestsBitfield()
        {
            return CompletedQuestsBitfield;
        }

        public bool IsQuestComplete(uint questId)
        {
            return CompletedQuestsBitfield.Get(questId - SCENARIO_START);
        }

        public void ForceQuestCompleteFlag(uint questId, bool flag)
        {
            if (flag)
                CompletedQuestsBitfield.Set(questId - SCENARIO_START);
            else 
                CompletedQuestsBitfield.Clear(questId - SCENARIO_START);
            ComputeAvailable();
        }

        public void Update(DateTime tick)
        {
            foreach (Quest quest in ActiveQuests)
                quest.Update(tick);
        }
    }
}
