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
using Meteor.Map.actors.director;
using Meteor.Map.DataObjects;

namespace Meteor.Map.Actors
{
    // Battle leve results on the player: unclaimed rewards and faction credits. Taking leves is
    // PlayerLeves.cs.
    partial class Player
    {
        // Faction credits cap at 1,000 per faction. 1 Brotherhood of the Broken Blade, 2 Azeyma's
        // Shields, 3 Horn and Hand.
        public const int FACTION_CREDIT_CAP = 1000;

        // Returns the amount actually gained.
        public int AddFactionCredits(int faction, int amount)
        {
            if (faction < 1 || faction > 3 || amount <= 0)
                return 0;
            int now = Database.GetFactionCredits(this, faction);
            int next = Math.Min(FACTION_CREDIT_CAP, now + amount);
            if (next != now)
                Database.SetFactionCredits(this, faction, next);
            return next - now;
        }

        // The faction that evaluates a leve (0-3): the card's Evaluation row and whose credits completion
        // pays. Faction leves 1000-1299 belong to their faction. The client has no column for the rest, so
        // by objective: Broken Blade for sweep/chase/hunt, Azeyma's Shields for survive/round, Horn and
        // Hand for orb/gather/detect. Fieldcraft has none.
        public static int GetGuildleveEvaluationFaction(uint glId)
        {
            if (glId >= 1000 && glId < 1300)
                return (int)(glId - 1000) / 100 + 1;
            GuildleveData gl = Server.GetGuildleveGamedata(glId);
            if (gl == null || gl.classType != 1)
                return 0;
            switch (gl.objective)
            {
                case 10051: case 10021: case 12010: case 10041: case 10042: case 10043:
                    return 3;   // orb, gather, detect
                case 10061: case 10081:
                    return 2;   // survive, round
                default:
                    return 1;   // sweep, chase, hunt
            }
        }

        public int GetGuildleveEvaluation(uint glId)
        {
            return GetGuildleveEvaluationFaction(glId);
        }

        // Regular leves: round(0.175 x level), +15% per star above 1, +25% for speed. Faction leves:
        // 20 + 5 x (stars - 1), +10 for speed. credits is the base part, bonus the difficulty and speed
        // part (50131 is sent when bonus > 0).
        public static void GetGuildleveFactionCredits(uint glId, int stars, bool speed, out int credits, out int bonus)
        {
            credits = bonus = 0;
            if (glId >= 1000 && glId < 1300)
            {
                credits = 20;
                bonus = 5 * (stars - 1) + (speed ? 10 : 0);
                return;
            }
            GuildleveData gl = Server.GetGuildleveGamedata(glId);
            if (gl == null)
                return;
            int level = Math.Max(1, Math.Min(50, (int)gl.level));
            credits = Math.Max(1, (int)Math.Round(0.175 * level));
            bonus = (int)Math.Round(credits * 0.15 * (stars - 1)) + (speed ? (int)Math.Round(credits * 0.25) : 0);
        }

        public int GetFactionCredits(int faction)
        {
            return Database.GetFactionCredits(this, faction);
        }

        public bool HasPendingGuildleveRewards()
        {
            return Database.GetPendingGuildleveRewards(this).Count > 0;
        }

        // Pays leve rewards nobody collected at the warp node (it faded, or the player zoned): 50082
        // says they wait at any aetheryte. Sends 50040 and the gil or item; returns how many were paid.
        public int ClaimPendingGuildleveRewards()
        {
            List<GuildleveDirector.LeveReward> rewards = Database.GetPendingGuildleveRewards(this);
            if (rewards.Count == 0)
                return 0;
            SendGameMessage(Server.GetWorldManager().GetActor(), 50040, 0x20);
            foreach (var r in rewards)
            {
                GuildleveDirector.GiveRewardItems(this, r);
                if (r.gil > 0)
                    SendGameMessage(Server.GetWorldManager().GetActor(), 25031, 0x20, (int)r.gil);   // "You obtain <n> gil."
                if (r.item2 != 0 && r.qty2 > 0)
                    SendGameMessage(Server.GetWorldManager().GetActor(), 25047, 0x20, (int)r.qty2, (int)r.item2, 1);
            }
            Database.ClearPendingGuildleveRewards(this);
            return rewards.Count;
        }
    }
}
