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

using Meteor.Map.Actors.QuestNS;
using Meteor.Map.DataObjects;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;

namespace Meteor.Map.Actors
{
    // A held local (crafting) leve's progress, stored as JSON in
    // characters_quest_guildleve_local.questData. Player.passiveGuildleves[n] mirrors
    // playerWork.questGuildleve[n] and work.guildleveId[8 + n].
    class PassiveGuildleve : Quest
    {
        private readonly Player owner;
        private Recipe targetRecipe;

        private byte currentDifficulty;
        private short currentCrafted;
        private short currentAttempt;

        private bool hasMaterials;

        private PassiveGuildleveData passiveGLData;

        // Null when the quest actor or its gamedata_passivegl_craft row is missing.
        public static PassiveGuildleve Create(Player owner, uint questId, byte difficulty, string questDataJson = null)
        {
            Quest staticQuest = Server.GetStaticActors(0xA0F00000 | questId) as Quest;
            PassiveGuildleveData data = Server.GetPassiveGLGamedata(questId);
            if (staticQuest == null || data == null)
                return null;
            return new PassiveGuildleve(staticQuest, owner, data, difficulty, questDataJson);
        }

        private PassiveGuildleve(Quest staticQuest, Player owner, PassiveGuildleveData data, byte difficulty, string questDataJson)
            : base(staticQuest)
        {
            this.owner = owner;
            passiveGLData = data;
            currentDifficulty = difficulty;

            Dictionary<string, object> questData = null;
            if (questDataJson != null)
            {
                try
                {
                    questData = JsonConvert.DeserializeObject<Dictionary<string, object>>(questDataJson);
                }
                catch (JsonException)
                {
                    questData = null;
                }
            }

            if (questData != null)
            {
                currentDifficulty = questData.ContainsKey("currentDifficulty") ? Convert.ToByte(questData["currentDifficulty"]) : difficulty;
                currentAttempt = questData.ContainsKey("currentAttempt") ? Convert.ToInt16(questData["currentAttempt"]) : (short)0;
                currentCrafted = questData.ContainsKey("currentCrafted") ? Convert.ToInt16(questData["currentCrafted"]) : (short)0;
                hasMaterials = questData.ContainsKey("hasMaterials") && Convert.ToBoolean(questData["hasMaterials"]);
            }

            if (currentDifficulty > 3)
                currentDifficulty = 3;

            targetRecipe = Server.ResolveRecipe()?.GetRecipeByItemID(passiveGLData.objectiveItemId[currentDifficulty]);
        }

        public void CraftSuccess()
        {
            if (targetRecipe != null)
                currentCrafted += (short)targetRecipe.resultQuantity;
            currentAttempt++;
            SaveData();
        }

        public void CraftFail()
        {
            currentAttempt++;
            SaveData();
        }

        // Journal Retry: a fresh set of attempts at the same difficulty.
        public void ResetProgress()
        {
            currentAttempt = 0;
            currentCrafted = 0;
            SaveData();
        }

        public void SetHasMaterials(bool value)
        {
            hasMaterials = value;
            SaveData();
        }

        public Recipe GetRecipe()
        {
            return targetRecipe;
        }

        public int GetObjectiveQuantity()
        {
            return passiveGLData.objectiveQuantity[currentDifficulty];
        }

        public int GetCurrentCrafted()
        {
            return currentCrafted;
        }

        public int GetRemainingMaterials()
        {
            return passiveGLData.numberOfAttempts[currentDifficulty] - currentAttempt;
        }

        public int GetCurrentAttempt()
        {
            return currentAttempt;
        }

        public int GetMaxAttempts()
        {
            return passiveGLData.numberOfAttempts[currentDifficulty];
        }

        public byte GetCurrentDifficulty()
        {
            return currentDifficulty;
        }

        public bool HasMaterials()
        {
            return hasMaterials;
        }

        public PassiveGuildleveData GetPassiveGLData()
        {
            return passiveGLData;
        }

        public void SaveData()
        {
            if (owner != null)
                Database.SaveLocalGuildleveData(owner, GetQuestId(), GetSerializedQuestData());
        }

        public string GetSerializedQuestData()
        {
            Dictionary<string, object> questData = new Dictionary<string, object>
            {
                { "currentDifficulty", currentDifficulty },
                { "currentAttempt", currentAttempt },
                { "currentCrafted", currentCrafted },
                { "hasMaterials", hasMaterials }
            };
            return JsonConvert.SerializeObject(questData, Formatting.None);
        }
    }
}
