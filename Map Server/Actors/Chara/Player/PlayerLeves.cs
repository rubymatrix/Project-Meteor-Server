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
using Meteor.Map.DataObjects;
using Meteor.Map.utils;
using Meteor.Map.actors.chara.player;

namespace Meteor.Map.Actors
{
    // Leve acquisition: allowances, taking regional and local leves at the publishers, local leve
    // turn-in and the leve history. Running a leve is GuildleveDirector's.
    partial class Player
    {
        // Allowances: +4 every 12 Earth hours, capped at 99; new characters start with 8; every leve type
        // uses one. The client only displays them: requestedData/activegl (JournalDetailWidget's
        // offerLimit) and the publishers' "(Leve allowances remaining: n)" lines.
        public const int LEVE_ALLOWANCE_START = 8;
        public const int LEVE_ALLOWANCE_GRANT = 4;
        public const int LEVE_ALLOWANCE_CAP = 99;
        public const int LEVE_ALLOWANCE_INTERVAL = 12 * 60 * 60;

        // Allowances a journal, counter or aetheryte retry of a failed leve costs. Retries are free here;
        // set 1 to charge one. JournalCommand.lua reads it through GetLeveRetryAllowanceCost().
        public const int LEVE_RETRY_ALLOWANCE_COST = 0;

        // Accept results for AcceptRegionalGuildleve / AcceptLocalGuildleve.
        public const int LEVE_ACCEPT_OK = 0;
        public const int LEVE_ACCEPT_INVALID = 1;
        public const int LEVE_ACCEPT_ALREADY_HELD = 2;
        public const int LEVE_ACCEPT_JOURNAL_FULL = 3;
        public const int LEVE_ACCEPT_NO_ALLOWANCE = 4;

        private const uint GIL_ITEM_ID = 1000001;
        private const uint BORDER_URGENT = 20004;

        private bool leveStateLoaded;
        private int leveAllowances;
        private uint leveAllowanceLastGrant;
        private HashSet<uint> completedGuildleves;

        private static uint UnixNow()
        {
            return (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        }

        // The 12-hour clock is per character, anchored at its first grant.
        private void RefreshLeveAllowances()
        {
            uint now = UnixNow();
            if (!leveStateLoaded)
            {
                leveStateLoaded = true;
                if (!Database.LoadLeveState(this, out leveAllowances, out leveAllowanceLastGrant))
                {
                    leveAllowances = LEVE_ALLOWANCE_START;
                    leveAllowanceLastGrant = now;
                    Database.SaveLeveState(this, leveAllowances, leveAllowanceLastGrant);
                    return;
                }
            }

            if (leveAllowanceLastGrant == 0 || leveAllowanceLastGrant > now)
            {
                leveAllowanceLastGrant = now;
                Database.SaveLeveState(this, leveAllowances, leveAllowanceLastGrant);
                return;
            }

            uint periods = (now - leveAllowanceLastGrant) / LEVE_ALLOWANCE_INTERVAL;
            if (periods == 0)
                return;

            long granted = (long)leveAllowances + (long)periods * LEVE_ALLOWANCE_GRANT;
            leveAllowances = (int)Math.Min(LEVE_ALLOWANCE_CAP, Math.Max(leveAllowances, granted));
            leveAllowanceLastGrant += periods * LEVE_ALLOWANCE_INTERVAL;
            Database.SaveLeveState(this, leveAllowances, leveAllowanceLastGrant);
        }

        public int GetLeveAllowances()
        {
            RefreshLeveAllowances();
            return leveAllowances;
        }

        public int GetLeveAllowanceSecondsToNextGrant()
        {
            RefreshLeveAllowances();
            long next = (long)leveAllowanceLastGrant + LEVE_ALLOWANCE_INTERVAL - UnixNow();
            return (int)Math.Max(0, next);
        }

        // False, and nothing spent, when there are not enough.
        public bool SpendLeveAllowance(int count = 1)
        {
            RefreshLeveAllowances();
            if (count < 0 || leveAllowances < count)
                return false;
            leveAllowances -= count;
            Database.SaveLeveState(this, leveAllowances, leveAllowanceLastGrant);
            return true;
        }

        public void AddLeveAllowances(int count)
        {
            SetLeveAllowances(GetLeveAllowances() + count);
        }

        public void SetLeveAllowances(int count)
        {
            RefreshLeveAllowances();
            leveAllowances = Math.Max(0, Math.Min(LEVE_ALLOWANCE_CAP, count));
            Database.SaveLeveState(this, leveAllowances, leveAllowanceLastGrant);
        }

        public int GetLeveRetryAllowanceCost()
        {
            return LEVE_RETRY_ALLOWANCE_COST;
        }


        // Battlecraft offers filter on the current class's level when it is a Disciple of War or Magic,
        // else on the highest DoW/DoM level.
        public int GetLeveBattleLevel()
        {
            int current = GetClass();
            if (current >= CLASSID_PUG && current <= CLASSID_CNJ)
                return GetLevel();

            int best = 0;
            foreach (int classId in new int[] { CLASSID_PUG, CLASSID_GLA, CLASSID_MRD, CLASSID_ARC, CLASSID_LNC, CLASSID_THM, CLASSID_CNJ })
                best = Math.Max(best, charaWork.battleSave.skillLevel[classId - 1]);
            return best;
        }

        public int GetClassLevel(int classId)
        {
            if (classId < 1 || classId > charaWork.battleSave.skillLevel.Length)
                return 0;
            return charaWork.battleSave.skillLevel[classId - 1];
        }


        // Card gil for a regional leve: round(4395 x level / 40), x1.5 for urgent leves (border 20004).
        // The warp node pays this scaled by stars (GuildleveDirector.GIL_PER_STAR).
        public static int GetGuildleveBaseGil(uint glId)
        {
            GuildleveData gl = Server.GetGuildleveGamedata(glId);
            if (gl == null)
                return 0;
            int level = Math.Max(1, Math.Min(50, (int)gl.level));
            int gil = (int)Math.Round(4395.0 * level / 40.0);
            if (gl.borderId == BORDER_URGENT)
                gil = (gil * 3 + 1) / 2;
            return gil;
        }

        // {rewardItem, rewardQty, subItem, subQty} as eventTalkDetail and eventGLSelectDetail show them.
        public uint[] GetGuildleveReward(uint glId)
        {
            return new uint[] { GIL_ITEM_ID, (uint)GetGuildleveBaseGil(glId), 0, 0 };
        }

        public int GetGuildleveRewardGil(uint glId)
        {
            return GetGuildleveBaseGil(glId);
        }

        public bool IsGuildleveRetained(uint id)
        {
            int slot = GetGuildleveWorkSlot(id);
            return slot != -1 && !work.guildleveDone[slot] && !work.guildleveChecked[slot];
        }

        public int GetRegionalGuildleveCount()
        {
            int count = 0;
            for (int i = 0; i < REGIONAL_GUILDLEVE_SLOTS; i++)
            {
                if (work.guildleveId[i] != 0)
                    count++;
            }
            return count;
        }

        public int GetLocalGuildleveCount()
        {
            int count = 0;
            for (int i = 0; i < playerWork.questGuildleve.Length; i++)
            {
                if (playerWork.questGuildleve[i] != 0)
                    count++;
            }
            return count;
        }

        // The 8 cards (0 = empty) of a regional pack; classType 1 battlecraft, 2 fieldcraft.
        public uint[] GetRegionalGuildleveCards(uint packId, uint classType, uint skill)
        {
            int level = classType == GuildleveOffers.CLASSTYPE_FIELDCRAFT ? GetClassLevel((int)skill) : GetLeveBattleLevel();
            return GuildleveOffers.BuildRegionalCards(this, packId, classType, skill, level);
        }

        // Retained in work.guildleveId[0-7]. The allowance is spent here; activating at the aetheryte is
        // free.
        public int AcceptRegionalGuildleve(uint glId)
        {
            GuildleveData gl = Server.GetGuildleveGamedata(glId);
            if (gl == null || IsLocalGuildleveId(glId))
                return LEVE_ACCEPT_INVALID;
            if (HasGuildleve(glId))
                return LEVE_ACCEPT_ALREADY_HELD;
            if (GetFreeGuildleveSlot() == -1)
                return LEVE_ACCEPT_JOURNAL_FULL;
            if (GetLeveAllowances() < 1)
                return LEVE_ACCEPT_NO_ALLOWANCE;

            AddGuildleve(glId);
            if (!HasGuildleve(glId))
                return LEVE_ACCEPT_INVALID;
            SpendLeveAllowance(1);
            return LEVE_ACCEPT_OK;
        }


        // askOfferQuest cards for a city's local publisher: two leves x four tiers.
        public uint[] GetLocalGuildleveCards(uint city, int classIndex, int rank)
        {
            return GuildleveOffers.BuildLocalCards(GuildleveOffers.BuildLocalOffers(this, city, classIndex, rank));
        }

        public int GetLocalGuildleveCardCount(uint city, int classIndex, int rank)
        {
            return GuildleveOffers.BuildLocalOffers(this, city, classIndex, rank).Count;
        }

        public int GetLocalGuildleveCardTier(int cardIndex)
        {
            return GuildleveOffers.GetLocalCardTier(cardIndex);
        }

        // Takes and activates a local leve at tier 0-3; one allowance. The materials count as handed over
        // on accept for every leve type, since fetching them from the client NPC would need per-NPC hooks.
        // They are virtual: CraftCommand counts attempts against the tier's numberOfAttempts.
        public int AcceptLocalGuildleve(uint questId, int tier)
        {
            if (!IsLocalGuildleveId(questId) || Server.GetPassiveGLGamedata(questId) == null)
                return LEVE_ACCEPT_INVALID;
            if (HasGuildleve(questId))
                return LEVE_ACCEPT_ALREADY_HELD;
            if (GetFreeLocalGuildleveSlot() == -1)
                return LEVE_ACCEPT_JOURNAL_FULL;
            if (GetLeveAllowances() < 1)
                return LEVE_ACCEPT_NO_ALLOWANCE;

            AddLocalGuildleve(questId, (byte)Math.Max(0, Math.Min(3, tier)));
            PassiveGuildleve progress = GetQuestGuildleve(questId);
            if (progress == null)
            {
                // Quest actor or passivegl row missing: undo rather than leave a dead journal entry.
                RemoveGuildleve(questId);
                return LEVE_ACCEPT_INVALID;
            }

            SpendLeveAllowance(1);
            progress.SetHasMaterials(true);
            SetGuildleveActive(questId);
            return LEVE_ACCEPT_OK;
        }

        // Items crafted reached the tier's quantity.
        public bool IsLocalGuildleveObjectiveMet(uint questId)
        {
            PassiveGuildleve progress = GetQuestGuildleve(questId);
            return progress != null && progress.GetCurrentCrafted() >= progress.GetObjectiveQuantity();
        }

        // Every attempt used without meeting the objective.
        public bool IsLocalGuildleveOutOfMaterials(uint questId)
        {
            PassiveGuildleve progress = GetQuestGuildleve(questId);
            return progress != null && !IsLocalGuildleveObjectiveMet(questId) && progress.GetRemainingMaterials() <= 0;
        }

        // Held local leves of this publisher's city that are ready to turn in.
        public uint[] GetLocalGuildlevesToTurnIn(uint city)
        {
            List<uint> ids = new List<uint>();
            int issuing = GuildleveOffers.GetLocalIssuingPlace(city);
            foreach (PassiveGuildleve progress in passiveGuildleves)
            {
                if (progress == null)
                    continue;
                uint id = progress.GetQuestId();
                if (progress.GetPassiveGLData().issuingLocation == issuing && IsLocalGuildleveObjectiveMet(id) && !IsGuildleveFailed(id))
                    ids.Add(id);
            }
            return ids.ToArray();
        }

        // Held local leves (any city) out of attempts and not yet marked failed.
        public uint[] GetLocalGuildlevesToFail()
        {
            List<uint> ids = new List<uint>();
            foreach (PassiveGuildleve progress in passiveGuildleves)
            {
                if (progress == null)
                    continue;
                uint id = progress.GetQuestId();
                if (IsLocalGuildleveOutOfMaterials(id) && !IsGuildleveFailed(id))
                    ids.Add(id);
            }
            return ids.ToArray();
        }

        // Grants the tier's reward item, records the completion (questGuildleveComplete bit and history)
        // and removes the leve. False if the reward doesn't fit. Only the base quantity is paid, since
        // crafting performance isn't tracked; the sheet has no gil or EXP for local leves. Turned in at
        // the issuing publisher rather than the client NPC named in deliveryDisplayName.
        public bool CompleteLocalGuildleve(uint questId)
        {
            PassiveGuildleve progress = GetQuestGuildleve(questId);
            if (progress == null || !IsLocalGuildleveObjectiveMet(questId))
                return false;

            PassiveGuildleveData data = progress.GetPassiveGLData();
            int tier = Math.Max(0, Math.Min(3, (int)progress.GetCurrentDifficulty()));
            int rewardItem = data.rewardItemId[tier];
            int rewardQty = data.rewardQuantity[tier];
            if (rewardItem > 0 && rewardQty > 0)
            {
                int result = GetItemPackage(ItemPackage.NORMAL).AddItem((uint)rewardItem, rewardQty, 1);
                if (result != ItemPackage.ERROR_SUCCESS)
                    return false;
            }

            RecordGuildleveCompletion(questId);
            RemoveGuildleve(questId);
            SendGameMessage(Server.GetWorldManager().GetActor(), 25086, 0x20, (object)questId); // "<Quest> complete!"
            return true;
        }

        // Retained in the journal; Retry resets it.
        public void FailLocalGuildleve(uint questId)
        {
            if (HasGuildleve(questId))
                SetGuildleveFailed(questId);
        }

        // Journal Retry: costs LEVE_RETRY_ALLOWANCE_COST allowances and returns a regional leve to retained
        // or restarts a local one with fresh materials.
        public bool RetryGuildleve(uint id)
        {
            if (!HasGuildleve(id) || !IsGuildleveFailed(id))
                return false;
            if (!SpendLeveAllowance(LEVE_RETRY_ALLOWANCE_COST))
                return false;

            if (IsLocalGuildleveId(id))
            {
                PassiveGuildleve progress = GetQuestGuildleve(id);
                progress?.ResetProgress();
                progress?.SetHasMaterials(true);
                SetGuildleveActive(id);
            }
            else
            {
                SetGuildleveRetained(id);
            }
            return true;
        }


        // Fills playerWork.questGuildleveComplete for local leves too.
        public void LoadGuildleveHistory()
        {
            completedGuildleves = Database.GetCompletedGuildleves(this);
            foreach (uint id in completedGuildleves)
                SetLocalCompleteBit(id);
        }

        public bool HasCompletedGuildleve(uint id)
        {
            if (completedGuildleves == null)
                LoadGuildleveHistory();
            return completedGuildleves.Contains(id);
        }

        public void RecordGuildleveCompletion(uint id)
        {
            if (completedGuildleves == null)
                LoadGuildleveHistory();
            completedGuildleves.Add(id);
            Database.AddGuildleveHistory(this, id);
            if (SetLocalCompleteBit(id))
            {
                // Byte-aligned range, as the client's own questCompleteG requests are.
                ushort first = (ushort)((id - LOCAL_GUILDLEVE_ID_BASE - 1) & ~7u);
                SendCompletedGuildleveQuests(first, (ushort)(first + 7));
            }
        }

        private bool SetLocalCompleteBit(uint id)
        {
            if (!IsLocalGuildleveId(id))
                return false;
            uint bit = id - LOCAL_GUILDLEVE_ID_BASE - 1;
            if (bit >= playerWork.questGuildleveComplete.Length)
                return false;
            playerWork.questGuildleveComplete[bit] = true;
            return true;
        }
    }
}
