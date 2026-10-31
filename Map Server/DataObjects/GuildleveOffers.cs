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

namespace Meteor.Map.DataObjects
{
    // The cards the leve publishers offer. The client sheets hold no offer lists, so the server picks
    // them. A pack's cards are the gamedata_guildleves rows whose start aetheryte is the pack's.
    // Pack hundreds by city: 0xx Limsa, 1xx Ul'dah, 2xx Gridania. N01-N07 are the battlecraft camps,
    // N31-N35 / N41-N45 / N51-N55 the fieldcraft camps for MIN / BTN / FSH.
    static class GuildleveOffers
    {
        // guildleve col 2 (location): 1 Limsa, 2 Gridania, 3 Ul'dah.
        public const uint CITY_LIMSA = 1;
        public const uint CITY_GRIDANIA = 2;
        public const uint CITY_ULDAH = 3;

        public const uint CLASSTYPE_BATTLECRAFT = 1;
        public const uint CLASSTYPE_FIELDCRAFT = 2;

        public const int CARD_COUNT = 8;   // client getMaxCardNum
        public const int LOCAL_LEVES_PER_PAGE = 2;

        // The offered cards rotate every 12 Earth hours, the allowance period.
        public const int OFFER_ROTATION_SECONDS = 12 * 60 * 60;

        // A leve is offered from 5 levels below its recommended rank; lower-level leves stay on offer.
        public const int OFFER_LEVEL_WINDOW = 5;

        // Tutorial battle leves (10801/10802 "My Very First Adventure", 12401, 11601) are offered
        // only from the Tutorial menu.
        private static readonly HashSet<uint> TutorialLeves = new HashSet<uint> { 10801, 10802, 12401, 11601 };

        private static Dictionary<uint, uint> packs = new Dictionary<uint, uint>();
        private static HashSet<uint> unused = new HashSet<uint>();

        public static void Load()
        {
            packs = Database.GetGuildlevePacks();
            unused = Database.GetUnusedGuildleves();
        }

        public static int GetPackCount()
        {
            return packs.Count;
        }

        public static uint GetPackAetheryte(uint packId)
        {
            uint aetheryte;
            return packs.TryGetValue(packId, out aetheryte) ? aetheryte : 0;
        }

        // First pack id of a city's block (guildlevePack hundreds).
        public static uint GetCityPackBase(uint city)
        {
            switch (city)
            {
                case CITY_LIMSA: return 0;
                case CITY_ULDAH: return 100;
                case CITY_GRIDANIA: return 200;
                default: return 0;
            }
        }

        public static uint GetCityFromPack(uint packId)
        {
            switch (packId / 100)
            {
                case 0: return CITY_LIMSA;
                case 1: return CITY_ULDAH;
                case 2: return CITY_GRIDANIA;
                default: return 0;
            }
        }

        public static uint GetBattlecraftFirstPack(uint city) { return GetCityPackBase(city) + 1; }
        public static uint GetBattlecraftLastPack(uint city) { return GetCityPackBase(city) + 7; }

        // skill 39/40/41 (MIN/BTN/FSH) -> first fieldcraft pack (N31/N41/N51).
        public static uint GetFieldcraftFirstPack(uint city, uint skill)
        {
            return GetCityPackBase(city) + 31 + (skill - 39) * 10;
        }

        public static uint GetFieldcraftLastPack(uint city, uint skill)
        {
            return GetFieldcraftFirstPack(city, skill) + 4;
        }

        // By actor class for the city counters, else by zone.
        public static uint GetPublisherCity(uint actorClassId, uint zoneId)
        {
            switch (actorClassId)
            {
                case 1500001: // Piralnaut (regional, Limsa)
                case 1000455: // T'mokkri (local, Limsa)
                    return CITY_LIMSA;
                case 1000457: // Gontrant (regional, Gridania)
                case 1000456: // Tierney (local, Gridania)
                    return CITY_GRIDANIA;
                case 1001371: // Totonawa (regional, Ul'dah)
                case 1001372: // Eustace (local, Ul'dah)
                    return CITY_ULDAH;
            }

            // City zones of the three counters (server_eventnpc_spawn_locations).
            switch (zoneId)
            {
                case 133: return CITY_LIMSA;
                case 155: return CITY_GRIDANIA;
                case 175: return CITY_ULDAH;
            }
            return 0;
        }

        public static bool IsTutorialLeve(uint id)
        {
            return TutorialLeves.Contains(id);
        }

        public static uint GetTutorialLeve(uint city)
        {
            switch (city)
            {
                case CITY_LIMSA: return 10801;
                case CITY_GRIDANIA: return 12401;
                case CITY_ULDAH: return 11601;
                default: return 0;
            }
        }

        // Named, has an objective, a real level and no faction credits.
        public static bool IsOfferable(GuildleveData gl)
        {
            return gl != null
                && !unused.Contains(gl.id)
                && gl.objective != 0
                && gl.level >= 1 && gl.level <= 50
                && gl.factionCreditRequired == 0
                && !TutorialLeves.Contains(gl.id);
        }

        // Up to 8 card ids for a regional pack (0 = empty card). classType 1 = battlecraft, 2 = fieldcraft
        // (skill 39/40/41 picks the gathering class). Held leves are left out, so the next eventTalkCard
        // after an accept lacks the taken card.
        public static uint[] BuildRegionalCards(Player player, uint packId, uint classType, uint skill, int playerLevel)
        {
            uint[] cards = new uint[CARD_COUNT];
            uint aetheryte = GetPackAetheryte(packId);
            uint city = GetCityFromPack(packId);
            if (aetheryte == 0 || city == 0)
                return cards;

            List<GuildleveData> pool = new List<GuildleveData>();
            foreach (GuildleveData gl in Server.GetAllGuildleveGamedata())
            {
                if (gl.aetheryte != aetheryte || gl.location != city || gl.classType != classType)
                    continue;
                if (classType == CLASSTYPE_FIELDCRAFT && gl.skill != skill)
                    continue;
                if (!IsOfferable(gl))
                    continue;
                if (playerLevel < gl.level - OFFER_LEVEL_WINDOW)
                    continue;
                pool.Add(gl);
            }

            // Rotate the whole pool before dropping held leves, so taking a card leaves the
            // other cards where they were.
            pool.Sort((a, b) => a.id.CompareTo(b.id));
            Rotate(pool, packId);

            int count = Math.Min(CARD_COUNT, pool.Count);
            List<uint> chosen = new List<uint>();
            for (int i = 0; i < count; i++)
            {
                if (player == null || !player.HasGuildleve(pool[i].id))
                    chosen.Add(pool[i].id);
            }
            chosen.Sort();
            for (int i = 0; i < chosen.Count; i++)
                cards[i] = chosen[i];
            return cards;
        }

        // Local leves a city's local publisher offers for one class and rank band, up to
        // LOCAL_LEVES_PER_PAGE quest ids (120xxx). classIndex 1-8 = CRP..CUL; rank 1-3 = "Level 1~",
        // "Level 20~", "Level 40~" (askOfferRank). A leve's band is the lowest of its tiers' levels.
        public static List<uint> BuildLocalOffers(Player player, uint city, int classIndex, int rank)
        {
            List<uint> result = new List<uint>();
            int issuing = GetLocalIssuingPlace(city);
            if (issuing == 0 || classIndex < 1 || classIndex > 8 || rank < 1 || rank > 3)
                return result;
            int classId = 28 + classIndex;
            int minLevel = rank == 1 ? 1 : (rank == 2 ? 20 : 40);
            int maxLevel = rank == 1 ? 19 : (rank == 2 ? 39 : 50);

            List<PassiveGuildleveData> pool = new List<PassiveGuildleveData>();
            foreach (PassiveGuildleveData gl in Server.GetAllPassiveGLGamedata())
            {
                if (gl.issuingLocation != issuing || gl.recommendedClass != classId)
                    continue;
                int band = Math.Min(Math.Min(gl.recommendedLevel[0], gl.recommendedLevel[1]), Math.Min(gl.recommendedLevel[2], gl.recommendedLevel[3]));
                if (band < minLevel || band > maxLevel)
                    continue;
                pool.Add(gl);
            }

            pool.Sort((a, b) => a.id.CompareTo(b.id));
            Rotate(pool, (uint)(city * 1000 + classIndex * 10 + rank));
            for (int i = 0; i < pool.Count && i < LOCAL_LEVES_PER_PAGE; i++)
            {
                if (player == null || !player.HasGuildleve(pool[i].id))
                    result.Add(pool[i].id);
            }
            result.Sort();
            return result;
        }

        // The client fixes each card slot's difficulty as 1,2,3,4,1,2,3,4
        // (PopulacePassiveGLPublisher.getPassiveGuildleveVariation), so each offered leve fills four
        // consecutive slots, one per tier: two leves per page.
        public static uint[] BuildLocalCards(List<uint> leves)
        {
            uint[] cards = new uint[CARD_COUNT];
            for (int i = 0; i < leves.Count && i < LOCAL_LEVES_PER_PAGE; i++)
            {
                for (int v = 0; v < 4; v++)
                    cards[i * 4 + v] = leves[i];
            }
            return cards;
        }

        // Card slot 1-8 -> difficulty tier index 0-3.
        public static int GetLocalCardTier(int cardIndex)
        {
            if (cardIndex < 1 || cardIndex > CARD_COUNT)
                return 0;
            return (cardIndex - 1) % 4;
        }

        // The issuing location is a place name id: the city.
        public static int GetLocalIssuingPlace(uint city)
        {
            switch (city)
            {
                case CITY_LIMSA: return 1051;
                case CITY_GRIDANIA: return 2001;
                case CITY_ULDAH: return 3051;
                default: return 0;
            }
        }

        // Deterministic shuffle per pool and rotation window, so every player sees the same cards
        // at the same counter until the next rotation.
        private static void Rotate<T>(List<T> pool, uint salt)
        {
            long window = DateTimeOffset.UtcNow.ToUnixTimeSeconds() / OFFER_ROTATION_SECONDS;
            Random rng = new Random(unchecked((int)(window * 7919 + salt * 104729)));
            for (int i = pool.Count - 1; i > 0; i--)
            {
                int j = rng.Next(i + 1);
                T tmp = pool[i];
                pool[i] = pool[j];
                pool[j] = tmp;
            }
        }
    }
}
