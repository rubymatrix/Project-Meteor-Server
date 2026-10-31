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

using Meteor.Common;
using System;
using System.Collections.Generic;
using Meteor.Map.DataObjects;
using Meteor.Map.DataObjects.chara;
using Meteor.Map.lua;
using Meteor.Map.packets.send.groups;
using Meteor.Map.packets.WorldPackets.Send.Group;
using Meteor.Map.utils;
using Meteor.Map.actors.group;
using Meteor.Map.actors.chara.player;
using Meteor.Map.actors.director;
using Meteor.Map.actors.chara.npc;
using Meteor.Map.actors.chara.ai;
using Meteor.Map.actors.chara.ai.controllers;
using Meteor.Map.actors.chara.ai.utils;
using Meteor.Map.actors.chara.ai.state;
using Meteor.Map.actors.chara;
using Meteor.Map.Actors.QuestNS;
using Meteor.Map.packets.send;
using Meteor.Map.packets.send.actor;
using Meteor.Map.packets.send.events;
using Meteor.Map.packets.send.actor.inventory;
using Meteor.Map.packets.send.player;
using Meteor.Map.packets.send.actor.battle;
using Meteor.Map.packets.receive.events;
using static Meteor.Map.LuaUtils;
using Meteor.Map.packets.send.actor.events;
using System.Text;

namespace Meteor.Map.Actors
{
    partial class Player : Character
    {
        public const int TIMER_TOTORAK = 0;
        public const int TIMER_DZEMAEL = 1;
        public const int TIMER_BOWL_OF_EMBERS_HARD = 2;
        public const int TIMER_BOWL_OF_EMBERS = 3;
        public const int TIMER_THORNMARCH = 4;
        public const int TIMER_AURUMVALE = 5;
        public const int TIMER_CUTTERSCRY = 6;
        public const int TIMER_BATTLE_ALEPORT = 7;
        public const int TIMER_BATTLE_HYRSTMILL = 8;
        public const int TIMER_BATTLE_GOLDENBAZAAR = 9;
        public const int TIMER_HOWLING_EYE_HARD = 10;
        public const int TIMER_HOWLING_EYE = 11;
        public const int TIMER_CASTRUM_TOWER = 12;
        public const int TIMER_BOWL_OF_EMBERS_EXTREME = 13;
        public const int TIMER_RIVENROAD = 14;
        public const int TIMER_RIVENROAD_HARD = 15;
        public const int TIMER_BEHEST = 16;
        public const int TIMER_COMPANYBEHEST = 17;
        public const int TIMER_RETURN = 18;
        public const int TIMER_SKIRMISH = 19;

        public const int NPCLS_GONE = 0;
        public const int NPCLS_INACTIVE = 1;
        public const int NPCLS_ACTIVE = 2;
        public const int NPCLS_ALERT = 3;

        public const int SLOT_MAINHAND = 0;
        public const int SLOT_OFFHAND = 1;
        public const int SLOT_THROWINGWEAPON = 4;
        public const int SLOT_PACK = 5;
        public const int SLOT_POUCH = 6;
        public const int SLOT_HEAD = 8;
        public const int SLOT_UNDERSHIRT = 9;
        public const int SLOT_BODY = 10;
        public const int SLOT_UNDERGARMENT = 11;
        public const int SLOT_LEGS = 12;
        public const int SLOT_HANDS = 13;
        public const int SLOT_BOOTS = 14;
        public const int SLOT_WAIST = 15;
        public const int SLOT_NECK = 16;
        public const int SLOT_EARS = 17;
        public const int SLOT_WRISTS = 19;
        public const int SLOT_RIGHTFINGER = 21;
        public const int SLOT_LEFTFINGER = 22;

        public static int[] MAXEXP = {570, 700, 880, 1100, 1500, 1800, 2300, 3200, 4300, 5000,                   //Level <= 10
                                     5900, 6800, 7700, 8700, 9700, 11000, 12000, 13000, 15000, 16000,            //Level <= 20
                                     20000, 22000, 23000, 25000, 27000, 29000, 31000, 33000, 35000, 38000,       //Level <= 30
                                     45000, 47000, 50000, 53000, 56000, 59000, 62000, 65000, 68000, 71000,       //Level <= 40
                                     74000, 78000, 81000, 85000, 89000, 92000, 96000, 100000, 100000, 110000};   //Level <= 50

        //Event Related
        public uint currentEventOwner = 0;
        public string currentEventName = "";
        public byte currentEventType = 0;
        public LuaCoroutine currentEventRunning;

        //Player Info
        public uint destinationZone;
        public ushort destinationSpawnType;
        public uint[] timers = new uint[20];
        public uint currentTitle;
        public uint playTime;
        public uint lastPlayTimeUpdate;
        public ushort gmLevel = 0;
        public bool isGM => gmLevel > 0;
        public bool isZoneChanging = true;
        private volatile bool seamlessCheckPending;
        public byte LoginDreamCode = 0;

        //Trading
        private Player otherTrader = null;
        private ReferencedItemPackage myOfferings;
        private bool isTradeAccepted = false;

        //GC Related
        public byte gcCurrent;
        public byte gcRankLimsa;
        public byte gcRankGridania;
        public byte gcRankUldah;

        //Mount Related
        public bool hasChocobo;
        public bool hasGoobbue;
        public string chocoboName;
        public byte mountState = 0;
        public byte chocoboAppearance;
        public uint rentalExpireTime = 0;
        public byte rentalMinLeft = 0;

        public uint achievementPoints;

        //Property Array Request Stuff
        private int lastPosition = 0;
        private int lastStep = 0;

        //Quest Actors (MUST MATCH playerWork.questScenario/questGuildleve)
        public Quest[] questScenario = new Quest[16];
        public uint[] questGuildleve = new uint[8];
        // Local leve progress, same index as playerWork.questGuildleve.
        public PassiveGuildleve[] passiveGuildleves = new PassiveGuildleve[8];

        // The craft menu's Recent and Awarded recipe lists, newest first. The menu shows 8.
        private const int MAX_RECIPE_LIST = 8;
        private readonly List<Recipe> recentRecipes = new List<Recipe>();
        private readonly List<Recipe> awardedRecipes = new List<Recipe>();
        public QuestStateManager questStateManager;

        //Aetheryte
        public uint homepoint = 0;
        public byte homepointInn = 0;

        //Nameplate Stuff
        public uint currentLSPlate = 0;
        public byte repairType = 0;

        //Retainer
        RetainerMeetingRelationGroup retainerMeetingGroup = null;
        public Retainer currentSpawnedRetainer = null;
        public bool sentRetainerSpawn = false;

        private List<Director> ownedDirectors = new List<Director>();
        private Director loginInitDirector = null;

        //SNpc (Path Companion)
        public string SNpcNickname { set; get; }
        public byte SNpcSkin { set; get; }
        public byte SNpcPersonality { set; get; }
        public short SNpcCoordinate { set; get; }

        List<ushort> hotbarSlotsToUpdate = new List<ushort>();

        public PlayerWork playerWork = new PlayerWork();

        public Session playerSession;

        public Player(Session cp, uint actorID) : base(actorID)
        {
            playerSession = cp;
            Name = String.Format("_pc{0:00000000}", actorID);
            className = "Player";

            moveSpeeds[0] = SetActorSpeedPacket.DEFAULT_STOP;
            moveSpeeds[1] = SetActorSpeedPacket.DEFAULT_WALK;
            moveSpeeds[2] = SetActorSpeedPacket.DEFAULT_RUN;
            moveSpeeds[3] = SetActorSpeedPacket.DEFAULT_ACTIVE;

            itemPackages[ItemPackage.NORMAL] = new ItemPackage(this, ItemPackage.MAXSIZE_NORMAL, ItemPackage.NORMAL);
            itemPackages[ItemPackage.KEYITEMS] = new ItemPackage(this, ItemPackage.MAXSIZE_KEYITEMS, ItemPackage.KEYITEMS);
            itemPackages[ItemPackage.CURRENCY_CRYSTALS] = new ItemPackage(this, ItemPackage.MAXSIZE_CURRANCY, ItemPackage.CURRENCY_CRYSTALS);
            itemPackages[ItemPackage.MELDREQUEST] = new ItemPackage(this, ItemPackage.MAXSIZE_MELDREQUEST, ItemPackage.MELDREQUEST);
            itemPackages[ItemPackage.BAZAAR] = new ItemPackage(this, ItemPackage.MAXSIZE_BAZAAR, ItemPackage.BAZAAR);
            itemPackages[ItemPackage.LOOT] = new ItemPackage(this, ItemPackage.MAXSIZE_LOOT, ItemPackage.LOOT);
            equipment = new ReferencedItemPackage(this, ItemPackage.MAXSIZE_EQUIPMENT, ItemPackage.EQUIPMENT);

            //Set the Skill level caps of all FFXIV (classes)skills to 50
            for (int i = 0; i < charaWork.battleSave.skillLevelCap.Length; i++)
            {
                if (i != CLASSID_PUG &&
                    i != CLASSID_MRD &&
                    i != CLASSID_GLA &&
                    i != CLASSID_MRD &&
                    i != CLASSID_ARC &&
                    i != CLASSID_LNC &&
                    i != CLASSID_THM &&
                    i != CLASSID_CNJ &&
                    i != CLASSID_CRP &&
                    i != CLASSID_BSM &&
                    i != CLASSID_ARM &&
                    i != CLASSID_GSM &&
                    i != CLASSID_LTW &&
                    i != CLASSID_WVR &&
                    i != CLASSID_ALC &&
                    i != CLASSID_CUL &&
                    i != CLASSID_MIN &&
                    i != CLASSID_BTN &&
                    i != CLASSID_FSH)
                    charaWork.battleSave.skillLevelCap[i] = 0xFF;
                else
                    charaWork.battleSave.skillLevelCap[i] = 50;

            }

            charaWork.property[0] = 1;
            charaWork.property[1] = 1;
            charaWork.property[2] = 1;
            charaWork.property[4] = 1;

            charaWork.command[0] = 0xA0F00000 | 21001;
            charaWork.command[1] = 0xA0F00000 | 21001;

            charaWork.command[2] = 0xA0F00000 | 21002;
            charaWork.command[3] = 0xA0F00000 | 12004;
            charaWork.command[4] = 0xA0F00000 | 21005;
            charaWork.command[5] = 0xA0F00000 | 21006;
            charaWork.command[6] = 0xA0F00000 | 21007;
            charaWork.command[7] = 0xA0F00000 | 12009;
            charaWork.command[8] = 0xA0F00000 | 12010;
            charaWork.command[9] = 0xA0F00000 | 12005;
            charaWork.command[10] = 0xA0F00000 | 12007;
            charaWork.command[11] = 0xA0F00000 | 12011;
            charaWork.command[12] = 0xA0F00000 | 22012;
            charaWork.command[13] = 0xA0F00000 | 22013;
            charaWork.command[14] = 0xA0F00000 | 29497;
            charaWork.command[15] = 0xA0F00000 | 22015;

            charaWork.commandAcquired[27150 - 26000] = true;

            playerWork.questGuildleveComplete[120050 - 120001] = true;

            for (int i = 0; i < charaWork.additionalCommandAcquired.Length; i++)
                charaWork.additionalCommandAcquired[i] = true;

            for (int i = 0; i < charaWork.commandCategory.Length; i++)
                charaWork.commandCategory[i] = 1;

            charaWork.battleTemp.generalParameter[3] = 1;

            charaWork.eventSave.bazaarTax = 5;
            charaWork.battleSave.potencial = 6.6f;

            charaWork.battleSave.negotiationFlag[0] = true;

            charaWork.commandCategory[0] = 1;
            charaWork.commandCategory[1] = 1;

            charaWork.parameterSave.commandSlot_compatibility[0] = true;
            charaWork.parameterSave.commandSlot_compatibility[1] = true;

            charaWork.commandBorder = 0x20;

            charaWork.parameterTemp.tp = 0;

            SNpcNickname = "???";
            SNpcSkin = 1;
            SNpcPersonality = 1;
            SNpcCoordinate = 1;

            Database.LoadPlayerCharacter(this);
            lastPlayTimeUpdate = Utils.UnixTimeStampUTC();

            this.aiContainer = new AIContainer(this, new PlayerController(this), null, new TargetFind(this));
            factionId = Meteor.Map.AI.Factions.Player;
            bonusAllotments = Database.LoadBonusAllotments(this);
            RefreshAcquiredCommands(false);
            CalculateBaseStats();
            AccrueRestedOffline();
            UpdateRemainBonusPoint(false);

            questStateManager = new QuestStateManager(this);
            questStateManager.Init(questScenario, playerWork.questScenarioComplete);
        }

        // The client keeps 3-18 and 23-34 in battleParameter. HP/MP/TP (0-2) are sent separately and
        // the client computes 19-22 itself.
        public static bool IsSyncedGeneralParameter(int index)
        {
            return (index >= 3 && index <= 18) || (index >= 23 && index <= 34);
        }

        public List<SubPacket> Create0x132Packets()
        {
            List<SubPacket> packets = new List<SubPacket>();
            packets.Add(_0x132Packet.BuildPacket(Id, 0xB, "commandForced"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0xA, "commandDefault"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x6, "commandWeak"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x4, "commandContent"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x6, "commandJudgeMode"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x100, "commandRequest"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x100, "widgetCreate"));
            packets.Add(_0x132Packet.BuildPacket(Id, 0x100, "macroRequest"));
            return packets;
        }

        /*        
         * PLAYER ARGS:
         * Unknown - Bool 
         * Unknown - Bool
         * Is Init Director - Bool
         * Unknown - Bool
         * Unknown - Number
         * Unknown - Bool
         * Timer Array - 20 Number
        */

        public override SubPacket CreateScriptBindPacket(Player requestPlayer)
        {
            List<LuaParam> lParams;
            if (IsMyPlayer(requestPlayer.Id))
            {
                if (loginInitDirector != null)
                    lParams = LuaUtils.CreateLuaParamList("/Chara/Player/Player_work", false, false, true, loginInitDirector, true, 0, false, timers, true);
                else
                    lParams = LuaUtils.CreateLuaParamList("/Chara/Player/Player_work", true, false, false, true, 0, false, timers, true);
            }
            else
                lParams = LuaUtils.CreateLuaParamList("/Chara/Player/Player_work", false, false, false, false, false, true);

            ActorInstantiatePacket.BuildPacket(Id, Name, className, lParams).DebugPrintSubPacket();


            return ActorInstantiatePacket.BuildPacket(Id, Name, className, lParams);
        }

        public override List<SubPacket> GetSpawnPackets(Player requestPlayer, ushort spawnType)
        {
            List<SubPacket> subpackets = new List<SubPacket>();
            subpackets.Add(CreateAddActorPacket(8));
            if (IsMyPlayer(requestPlayer.Id))
                subpackets.AddRange(Create0x132Packets());
            subpackets.Add(CreateSpeedPacket());
            subpackets.Add(CreateSpawnPositonPacket(this, spawnType));
            subpackets.Add(CreateAppearancePacket());
            subpackets.Add(CreateNamePacket());
            subpackets.Add(_0xFPacket.BuildPacket(Id));
            // A death still to replay: the player's own bundle says passive; others see the KO.
            if (pendingDeathReplay && IsMyPlayer(requestPlayer.Id))
                subpackets.Add(SetActorStatePacket.BuildPacket(Id, SetActorStatePacket.MAIN_STATE_PASSIVE, 0));
            else
                subpackets.Add(CreateStatePacket());
            subpackets.Add(CreateSubStatePacket());
            subpackets.Add(CreateInitStatusPacket());
            subpackets.Add(CreateSetActorIconPacket());
            subpackets.Add(CreateIsZoneingPacket());
            subpackets.AddRange(CreatePlayerRelatedPackets(requestPlayer.Id));
            subpackets.Add(CreateScriptBindPacket(requestPlayer));
            return subpackets;
        }

        public new SubPacket CreateNamePacket()
        {
            bool isMale = true;
            switch (playerWork.tribe)
            {
                case 2:
                case 5:
                case 7:
                case 9:
                case 11:
                case 12:
                case 13:
                    isMale = false;
                    break;
            }
            return SetActorNamePacket.BuildPacket(Id, DisplayName != null ? 0 : LocalizedDisplayName, LocalizedDisplayName == 0xFFFFFFFF | LocalizedDisplayName == 0x0 | DisplayName != null ? DisplayName : "", isMale);
        }

        public List<SubPacket> CreatePlayerRelatedPackets(uint requestingPlayerActorId)
        {
            List<SubPacket> subpackets = new List<SubPacket>();

            if (gcCurrent != 0)
                subpackets.Add(SetGrandCompanyPacket.BuildPacket(Id, gcCurrent, gcRankLimsa, gcRankGridania, gcRankUldah));

            if (currentTitle != 0)
                subpackets.Add(SetPlayerTitlePacket.BuildPacket(Id, currentTitle));

            if (currentJob != 0)
                subpackets.Add(SetCurrentJobPacket.BuildPacket(Id, currentJob));

            if (IsMyPlayer(requestingPlayerActorId))
            {
                subpackets.Add(SetSpecialEventWorkPacket.BuildPacket(Id));

                if (hasChocobo && chocoboName != null && !chocoboName.Equals(""))
                {
                    subpackets.Add(SetChocoboNamePacket.BuildPacket(Id, chocoboName));
                    subpackets.Add(SetHasChocoboPacket.BuildPacket(Id, hasChocobo));
                }

                if (hasGoobbue)
                    subpackets.Add(SetHasGoobbuePacket.BuildPacket(Id, hasGoobbue));

                subpackets.Add(SetAchievementPointsPacket.BuildPacket(Id, achievementPoints));

                subpackets.Add(Database.GetLatestAchievements(this));
                subpackets.Add(Database.GetAchievementsPacket(this));
            }

            if (mountState == 1)
                subpackets.Add(SetCurrentMountChocoboPacket.BuildPacket(Id, chocoboAppearance, rentalExpireTime, rentalMinLeft));
            else if (mountState == 2)
                subpackets.Add(SetCurrentMountGoobbuePacket.BuildPacket(Id, 1));

            //Inn Packets (Dream, Cutscenes, Armoire)   
            if (CurrentArea.isInn)
            {
                SetCutsceneBookPacket cutsceneBookPacket = new SetCutsceneBookPacket();
                bool[] testComplete = new bool[2048]; //TODO: Change to playerwork.scenarioComplete
                for (int i = 0; i < 2048; i++)
                    testComplete[i] = true;
                QueuePacket(cutsceneBookPacket.BuildPacket(Id, SNpcNickname, SNpcSkin, SNpcPersonality, SNpcCoordinate, testComplete));
                QueuePacket(SetPlayerDreamPacket.BuildPacket(Id, LoginDreamCode, GetInnCode()));
            }

            return subpackets;
        }

        public override List<SubPacket> GetInitPackets()
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("/_init", this);

            propPacketUtil.AddProperty("charaWork.eventSave.bazaarTax");
            propPacketUtil.AddProperty("charaWork.battleSave.potencial");

            //Properties
            for (int i = 0; i < charaWork.property.Length; i++)
            {
                if (charaWork.property[i] != 0)
                    propPacketUtil.AddProperty(String.Format("charaWork.property[{0}]", i));
            }

            //Parameters
            propPacketUtil.AddProperty("charaWork.parameterSave.hp[0]");
            propPacketUtil.AddProperty("charaWork.parameterSave.hpMax[0]");
            propPacketUtil.AddProperty("charaWork.parameterSave.mp");
            propPacketUtil.AddProperty("charaWork.parameterSave.mpMax");
            propPacketUtil.AddProperty("charaWork.parameterTemp.tp");
            propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkill[0]");
            propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkillLevel");

            //Status Times
            for (int i = 0; i < charaWork.statusShownTime.Length; i++)
            {
                if (charaWork.statusShownTime[i] != 0)
                    propPacketUtil.AddProperty(String.Format("charaWork.statusShownTime[{0}]", i));
            }

            //General Parameters
            for (int i = 3; i < charaWork.battleTemp.generalParameter.Length; i++)
            {
                if (IsSyncedGeneralParameter(i) && charaWork.battleTemp.generalParameter[i] != 0)
                    propPacketUtil.AddProperty(String.Format("charaWork.battleTemp.generalParameter[{0}]", i));
            }

            propPacketUtil.AddProperty("charaWork.battleTemp.castGauge_speed[0]");
            propPacketUtil.AddProperty("charaWork.battleTemp.castGauge_speed[1]");

            //Battle Save Skillpoint
            propPacketUtil.AddProperty(String.Format("charaWork.battleSave.skillPoint[{0}]", charaWork.parameterSave.state_mainSkill[0] - 1));

            //Commands
            propPacketUtil.AddProperty("charaWork.commandBorder");

            propPacketUtil.AddProperty("charaWork.battleSave.negotiationFlag[0]");

            for (int i = 0; i < charaWork.command.Length; i++)
            {
                if (charaWork.command[i] != 0)
                {
                    propPacketUtil.AddProperty(String.Format("charaWork.command[{0}]", i));
                    //Recast Timers
                    if (i >= charaWork.commandBorder)
                    {
                        propPacketUtil.AddProperty(String.Format("charaWork.parameterTemp.maxCommandRecastTime[{0}]", i - charaWork.commandBorder));
                        propPacketUtil.AddProperty(String.Format("charaWork.parameterSave.commandSlot_recastTime[{0}]", i - charaWork.commandBorder));
                    }
                }
            }

            for (int i = 0; i < charaWork.commandCategory.Length; i++)
            {
                charaWork.commandCategory[i] = 1;
                if (charaWork.commandCategory[i] != 0)
                    propPacketUtil.AddProperty(String.Format("charaWork.commandCategory[{0}]", i));
            }

            for (int i = 0; i < charaWork.commandAcquired.Length; i++)
            {
                if (charaWork.commandAcquired[i] != false)
                    propPacketUtil.AddProperty(String.Format("charaWork.commandAcquired[{0}]", i));
            }

            for (int i = 0; i < charaWork.additionalCommandAcquired.Length; i++)
            {
                if (charaWork.additionalCommandAcquired[i] != false)
                    propPacketUtil.AddProperty(String.Format("charaWork.additionalCommandAcquired[{0}]", i));
            }

            for (int i = 0; i < charaWork.parameterSave.commandSlot_compatibility.Length; i++)
            {
                charaWork.parameterSave.commandSlot_compatibility[i] = true;
                if (charaWork.parameterSave.commandSlot_compatibility[i])
                    propPacketUtil.AddProperty(String.Format("charaWork.parameterSave.commandSlot_compatibility[{0}]", i));
            }

            for (int i = 0; i < charaWork.parameterSave.commandSlot_recastTime.Length; i++)
            {
                if (charaWork.parameterSave.commandSlot_recastTime[i] != 0)
                    propPacketUtil.AddProperty(String.Format("charaWork.parameterSave.commandSlot_recastTime[{0}]", i));
            }

            //System
            propPacketUtil.AddProperty("charaWork.parameterTemp.forceControl_float_forClientSelf[0]");
            propPacketUtil.AddProperty("charaWork.parameterTemp.forceControl_float_forClientSelf[1]");
            propPacketUtil.AddProperty("charaWork.parameterTemp.forceControl_int16_forClientSelf[0]");
            propPacketUtil.AddProperty("charaWork.parameterTemp.forceControl_int16_forClientSelf[1]");

            charaWork.parameterTemp.otherClassAbilityCount[0] = 4;
            charaWork.parameterTemp.otherClassAbilityCount[1] = 5;
            charaWork.parameterTemp.giftCount[1] = 5;

            propPacketUtil.AddProperty("charaWork.parameterTemp.otherClassAbilityCount[0]");
            propPacketUtil.AddProperty("charaWork.parameterTemp.otherClassAbilityCount[1]");
            propPacketUtil.AddProperty("charaWork.parameterTemp.giftCount[1]");

            propPacketUtil.AddProperty("charaWork.depictionJudge");

            //Scenario
            for (int i = 0; i < playerWork.questScenario.Length; i++)
            {
                if (playerWork.questScenario[i] != 0)
                    propPacketUtil.AddProperty(String.Format("playerWork.questScenario[{0}]", i));
            }

            //Guildleve - Local
            for (int i = 0; i < playerWork.questGuildleve.Length; i++)
            {
                if (playerWork.questGuildleve[i] != 0)
                    propPacketUtil.AddProperty(String.Format("playerWork.questGuildleve[{0}]", i));
            }

            //Guildleve - Regional
            for (int i = 0; i < work.guildleveId.Length; i++)
            {
                if (work.guildleveId[i] != 0)
                    propPacketUtil.AddProperty(String.Format("work.guildleveId[{0}]", i));
                if (work.guildleveDone[i] != false)
                    propPacketUtil.AddProperty(String.Format("work.guildleveDone[{0}]", i));
                if (work.guildleveChecked[i] != false)
                    propPacketUtil.AddProperty(String.Format("work.guildleveChecked[{0}]", i));
            }

            //Bazaar
            CheckBazaarFlags(true);
            if (charaWork.eventSave.repairType != 0)
                propPacketUtil.AddProperty("charaWork.eventSave.repairType");
            if (charaWork.eventTemp.bazaarRetail)
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarRetail");
            if (charaWork.eventTemp.bazaarRepair)
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarRepair");
            if (charaWork.eventTemp.bazaarMateria)
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarMateria");

            //NPC Linkshell            
            for (int i = 0; i < playerWork.npcLinkshellChatCalling.Length; i++)
            {
                if (playerWork.npcLinkshellChatCalling[i] != false)
                    propPacketUtil.AddProperty(String.Format("playerWork.npcLinkshellChatCalling[{0}]", i));
                if (playerWork.npcLinkshellChatExtra[i] != false)
                    propPacketUtil.AddProperty(String.Format("playerWork.npcLinkshellChatExtra[{0}]", i));
            }

            propPacketUtil.AddProperty("playerWork.restBonusExpRate");
            if (playerWork.isRemainBonusPoint)
                propPacketUtil.AddProperty("playerWork.isRemainBonusPoint");

            //Profile
            propPacketUtil.AddProperty("playerWork.tribe");
            propPacketUtil.AddProperty("playerWork.guardian");
            propPacketUtil.AddProperty("playerWork.birthdayMonth");
            propPacketUtil.AddProperty("playerWork.birthdayDay");
            propPacketUtil.AddProperty("playerWork.initialTown");

            return propPacketUtil.Done();
        }

        public void SendSeamlessZoneInPackets()
        {
            QueuePacket(SetMusicPacket.BuildPacket(Id, GetZoneMusic(), SetMusicPacket.EFFECT_FADEIN));
            QueuePacket(SetWeatherPacket.BuildPacket(Id, SetWeatherPacket.WEATHER_CLEAR, 1));
        }

        public void SendZoneInPackets(WorldManager world, ushort spawnType)
        {
            QueuePacket(SetActorIsZoningPacket.BuildPacket(Id, false));
            QueuePacket(SetDalamudPacket.BuildPacket(Id, 7));

            //Music Packets (mode 1 replaces whatever is playing, battle track included)
            ResetBattleMusic();
            if (currentMainState == SetActorStatePacket.MAIN_STATE_MOUNTED)
            {
                if (rentalExpireTime != 0)
                    QueuePacket(SetMusicPacket.BuildPacket(Id, 64, 0x01)); //Rental
                else
                {
                    if (mountState == 1)
                        QueuePacket(SetMusicPacket.BuildPacket(Id, 83, 0x01)); //Mount
                    else
                        QueuePacket(SetMusicPacket.BuildPacket(Id, 98, 0x01)); //Goobbue
                }
            }
            else
                QueuePacket(SetMusicPacket.BuildPacket(Id, GetZoneMusic(), 0x01)); //Zone (or a running leve's track)

            QueuePacket(SetWeatherPacket.BuildPacket(Id, SetWeatherPacket.WEATHER_CLEAR, 1));

            QueuePacket(SetMapPacket.BuildPacket(Id, CurrentArea.RegionId, CurrentArea.ZoneId));

            // Zoning in KO'd: spawn passive in the client and replay the death after the zone-in.
            if (IsDead() && !skipDeathReplayOnce)
            {
                pendingDeathReplay = true;
                deathReplayAt = DateTime.MaxValue;
            }
            skipDeathReplayOnce = false;

            QueuePackets(GetSpawnPackets(this, spawnType));

            #region Inventory & Equipment
            QueuePacket(InventoryBeginChangePacket.BuildPacket(Id, true));
            itemPackages[ItemPackage.NORMAL].SendFullPackage(this);
            itemPackages[ItemPackage.CURRENCY_CRYSTALS].SendFullPackage(this);
            itemPackages[ItemPackage.KEYITEMS].SendFullPackage(this);
            itemPackages[ItemPackage.BAZAAR].SendFullPackage(this);
            itemPackages[ItemPackage.MELDREQUEST].SendFullPackage(this);
            itemPackages[ItemPackage.LOOT].SendFullPackage(this);
            equipment.SendUpdate(this);
            playerSession.QueuePacket(InventoryEndChangePacket.BuildPacket(Id));
            #endregion

            playerSession.QueuePacket(GetInitPackets());

            List<SubPacket> areaMasterSpawn = CurrentArea.GetSpawnPackets();
            List<SubPacket> debugSpawn = world.GetDebugActor().GetSpawnPackets();
            List<SubPacket> worldMasterSpawn = world.GetActor().GetSpawnPackets();

            playerSession.QueuePacket(areaMasterSpawn);
            playerSession.QueuePacket(debugSpawn);
            playerSession.QueuePacket(worldMasterSpawn);

            if (CurrentArea.GetWeatherDirector() != null)
            {
                playerSession.QueuePacket(CurrentArea.GetWeatherDirector().GetSpawnPackets());
            }

            foreach (Director director in ownedDirectors)
            {
                QueuePackets(director.GetSpawnPackets());
                QueuePackets(director.GetInitPackets());
            }

            if (currentContentGroup != null)
                currentContentGroup.SendGroupPackets(playerSession);

            if (currentParty != null)
                currentParty.SendGroupPackets(playerSession);
            SendOwnPartyOccupancy();

            SendInstanceUpdate();
        }

        private void SendRemoveInventoryPackets(List<ushort> slots)
        {
            int currentIndex = 0;

            while (true)
            {
                if (slots.Count - currentIndex >= 64)
                    QueuePacket(InventoryRemoveX64Packet.BuildPacket(Id, slots, ref currentIndex));
                else if (slots.Count - currentIndex >= 32)
                    QueuePacket(InventoryRemoveX32Packet.BuildPacket(Id, slots, ref currentIndex));
                else if (slots.Count - currentIndex >= 16)
                    QueuePacket(InventoryRemoveX16Packet.BuildPacket(Id, slots, ref currentIndex));
                else if (slots.Count - currentIndex >= 8)
                    QueuePacket(InventoryRemoveX08Packet.BuildPacket(Id, slots, ref currentIndex));
                else if (slots.Count - currentIndex == 1)
                    QueuePacket(InventoryRemoveX01Packet.BuildPacket(Id, slots[currentIndex]));
                else
                    break;
            }

        }

        public bool IsMyPlayer(uint otherActorId)
        {
            return Id == otherActorId;
        }

        public void QueuePacket(SubPacket packet)

        {
            playerSession.QueuePacket(packet);
        }

        public void QueuePackets(List<SubPacket> packets)
        {
            playerSession.QueuePacket(packets);
        }

        public void SendPacket(string path)
        {
            try
            {
                BasePacket packet = new BasePacket(path);

                packet.ReplaceActorID(Id);
                var packets = packet.GetSubpackets();
                QueuePackets(packets);
            }
            catch (Exception e)
            {
                this.SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM_ERROR, "[SendPacket]", "Unable to send packet.");
                this.SendMessage(SendMessagePacket.MESSAGE_TYPE_SYSTEM_ERROR, "[SendPacket]", e.Message);
            }
        }

        public void BroadcastPackets(List<SubPacket> packets, bool sendToSelf)
        {
            foreach (SubPacket packet in packets)
            {
                if (sendToSelf)
                {

                    SubPacket clonedPacket = new SubPacket(packet, Id);
                    QueuePacket(clonedPacket);
                }

                foreach (Actor a in playerSession.actorInstanceList)
                {
                    if (a is Player)
                    {
                        Player p = (Player)a;

                        if (p.Equals(this))
                            continue;

                        SubPacket clonedPacket = new SubPacket(packet, a.Id);
                        p.QueuePacket(clonedPacket);
                    }
                }
            }
        }

        public void BroadcastPacket(SubPacket packet, bool sendToSelf)
        {
            if (sendToSelf)
            {
                SubPacket clonedPacket = new SubPacket(packet, Id);
                QueuePacket(clonedPacket);
            }

            foreach (Actor a in playerSession.actorInstanceList)
            {
                if (a is Player)
                {
                    Player p = (Player)a;

                    if (p.Equals(this))
                        continue;

                    SubPacket clonedPacket = new SubPacket(packet, a.Id);
                    p.QueuePacket(clonedPacket);
                }
            }
        }

        public void ChangeAnimation(uint animId)
        {
            Actor a = CurrentArea.FindActorInArea(currentTarget);
            if (a is Npc)
                ((Npc)a).animationId = animId;
        }

        public void SetDCFlag(bool flag)
        {
            if (flag)
            {
                BroadcastPacket(SetActorIconPacket.BuildPacket(Id, SetActorIconPacket.DISCONNECTING), true);
            }
            else
            {
                if (isGM)
                    BroadcastPacket(SetActorIconPacket.BuildPacket(Id, SetActorIconPacket.ISGM), true);
                else
                    BroadcastPacket(SetActorIconPacket.BuildPacket(Id, 0), true);
            }
        }

        public void CleanupAndSave()
        {
            LuaEngine.GetInstance().CancelPlayerEvent(this);
            playerSession.LockUpdates(true);

            Database.SetRestInnLogoutTime(this, CurrentArea != null && CurrentArea.isInn ? Utils.UnixTimeStampUTC() : 0);

            //Remove actor from zone and main server list
            Server.GetWorldManager().ClearMergedZone(this);
            CurrentArea.RemoveActorFromZone(this);

            //Set Destination to 0
            this.destinationZone = 0;
            this.destinationSpawnType = 0;

            //Clean up parties
            RemoveFromCurrentPartyAndCleanup();

            //Save Player
            Database.SavePlayerPlayTime(this);
            Database.SavePlayerPosition(this);
            Database.SavePlayerStatusEffects(this);
            Database.SavePlayerMainState(this, IsDead() || pendingDeathReplay);

            //Save Quests
            foreach (Quest quest in questScenario)
            {
                if (quest != null)
                    quest.GetData().Save();
            }
        }

        public void CleanupAndSave(uint destinationZone, ushort spawnType, float destinationX, float destinationY, float destinationZ, float destinationRot)
        {
            LuaEngine.GetInstance().CancelPlayerEvent(this);
            playerSession.LockUpdates(true);

            //Remove actor from zone and main server list
            Server.GetWorldManager().ClearMergedZone(this);
            CurrentArea.RemoveActorFromZone(this);

            //Clean up parties
            RemoveFromCurrentPartyAndCleanup();

            //Set destination
            this.destinationZone = destinationZone;
            this.destinationSpawnType = spawnType;
            this.positionX = destinationX;
            this.positionY = destinationY;
            this.positionZ = destinationZ;
            this.rotation = destinationRot;

            this.statusEffects.RemoveStatusEffectsByFlags((uint)StatusEffectFlags.LoseOnZoning);

            //Save Player
            Database.SavePlayerPlayTime(this);
            Database.SavePlayerPosition(this);
            Database.SavePlayerStatusEffects(this);
        }

        public void SendMessage(uint logType, string sender, string message)
        {
            QueuePacket(SendMessagePacket.BuildPacket(Id, logType, sender, message));
        }

        //Only use at logout since it's intensive
        private byte GetInnCode()
        {
            if (CurrentArea.isInn)
            {
                Vector3 position = new Vector3(positionX, 0, positionZ);
                if (Utils.Distance(position, new Vector3(0, 0, 0)) <= 20f)
                    return 3;
                else if (Utils.Distance(position, new Vector3(160, 0, 160)) <= 20f)
                    return 2;
                else if (Utils.Distance(position, new Vector3(-160, 0, -160)) <= 20f)
                    return 1;
            }
            return 0;
        }

        public void SetLoginDreamCode(byte code)
        {
            LoginDreamCode = code;
        }

        public byte GetLoginDreamCode()
        {
            return LoginDreamCode;
        }

        public void SetSleeping()
        {
            playerSession.LockUpdates(true);
            switch (GetInnCode())
            {
                case 1:
                    positionX = -162.42f;
                    positionY = 0f;
                    positionZ = -154.21f;
                    rotation = 1.56f;
                    break;
                case 2:
                    positionX = 157.55f;
                    positionY = 0f;
                    positionZ = 165.05f;
                    rotation = 1.53f;
                    break;
                case 3:
                    positionX = -2.65f;
                    positionY = 0f;
                    positionZ = 3.94f;
                    rotation = 1.52f;
                    break;
            }
        }

        public void Logout()
        {
            // todo: really this should be in CleanupAndSave but we might want logout/disconnect handled separately for some effects
            QueuePacket(LogoutPacket.BuildPacket(Id));
            statusEffects.RemoveStatusEffectsByFlags((uint)StatusEffectFlags.LoseOnLogout);
            CleanupAndSave();
        }

        public void QuitGame()
        {
            QueuePacket(QuitPacket.BuildPacket(Id));
            statusEffects.RemoveStatusEffectsByFlags((uint)StatusEffectFlags.LoseOnLogout);
            CleanupAndSave();
        }

        public uint GetPlayTime(bool doUpdate)
        {
            if (doUpdate)
            {
                uint curTime = Utils.UnixTimeStampUTC();
                playTime += curTime - lastPlayTimeUpdate;
                lastPlayTimeUpdate = curTime;
            }

            return playTime;
        }

        public void SavePlayTime()
        {
            Database.SavePlayerPlayTime(this);
        }

        public void ChangeMusic(ushort musicId)
        {
            QueuePacket(SetMusicPacket.BuildPacket(Id, musicId, 1));
        }

        public void ChangeMusic(ushort musicId, ushort musicTrackMode)
        {
            QueuePacket(SetMusicPacket.BuildPacket(Id, musicId, musicTrackMode));
        }

        // Back to the zone's own track, after crafting and the like change it.
        public void ResetMusic()
        {
            ResetBattleMusic();
            ChangeMusic(GetZoneMusic());
        }

        // The battle track is pushed once per fight and popped back to the zone track a few seconds
        // after the last enemy lets go. KO keeps whatever is playing.
        private bool battleMusicActive;
        // Set by a sheathe: hate alone must not bring the battle track back until the next engage.
        private bool battleMusicSuppressed;
        private DateTime outOfCombatSince = DateTime.MinValue;
        private DateTime nextBattleMusicCheck = DateTime.MinValue;
        public const double BATTLE_MUSIC_END_GRACE_SECONDS = 5;

        public bool IsBattleMusicActive()
        {
            return battleMusicActive;
        }

        // Outside combat a leve's participants hear the leve's track.
        public ushort GetZoneMusic()
        {
            ushort leve = GetLeveMusic();
            if (leve != 0)
                return leve;
            return CurrentArea == null ? (ushort)0 : CurrentArea.bgmDay;
        }

        // Non-zero while this player takes part in a placed or running leve. Leaving the leve in any
        // way drops it, so nothing here needs clearing.
        public ushort GetLeveMusic()
        {
            GuildleveDirector leve = GetGuildleveDirector();
            return leve == null ? (ushort)0 : leve.GetLeveMusic(this);
        }

        // The leve track is the leve's battle music: it replaces the battle push until the leve ends.
        public void StartLeveMusic()
        {
            ushort leve = GetLeveMusic();
            if (leve == 0)
                return;
            battleMusicActive = false;
            outOfCombatSince = DateTime.MinValue;
            QueuePacket(SetMusicPacket.BuildPacket(Id, leve, SetMusicPacket.EFFECT_FADEIN));
        }

        // The leve is over for this player: the battle track if a fight is still on, else the zone's.
        public void RestoreFieldMusic()
        {
            if (playerSession == null || CurrentArea == null || isZoneChanging)
                return;
            battleMusicActive = false;
            outOfCombatSince = DateTime.MinValue;
            if (IsAlive() && !battleMusicSuppressed && IsInCombat() && CurrentArea.bgmBattle != 0
                && currentMainState != SetActorStatePacket.MAIN_STATE_MOUNTED)
            {
                StartBattleMusic();
                return;
            }
            ushort zoneMusic = GetZoneMusic();
            if (zoneMusic != 0)
                QueuePacket(SetMusicPacket.BuildPacket(Id, zoneMusic, SetMusicPacket.EFFECT_FADEIN));
        }

        // Only an engage overrides a sheathe's suppression.
        public void StartBattleMusic(bool fromEngage = false)
        {
            if (fromEngage)
                battleMusicSuppressed = false;
            else if (battleMusicSuppressed)
                return;
            outOfCombatSince = DateTime.MinValue;
            if (battleMusicActive || CurrentArea == null || CurrentArea.bgmBattle == 0 || isZoneChanging || !IsAlive())
                return;
            // A leve participant already hears the leve's battle track; fights don't switch it.
            if (GetLeveMusic() != 0)
                return;
            if (currentMainState == SetActorStatePacket.MAIN_STATE_MOUNTED)
                return;
            battleMusicActive = true;
            // Immediate, not fade-in: a fade-in starts its track 2 s later, after the client has
            // already ignored a zone-track request for the track still playing.
            QueuePacket(SetMusicPacket.BuildPacket(Id, CurrentArea.bgmBattle, SetMusicPacket.EFFECT_IMMEDIATE));
        }

        public void EndBattleMusic()
        {
            if (!battleMusicActive)
                return;
            battleMusicActive = false;
            outOfCombatSince = DateTime.MinValue;
            ushort zoneMusic = GetZoneMusic();
            if (zoneMusic != 0)
                QueuePacket(SetMusicPacket.BuildPacket(Id, zoneMusic, SetMusicPacket.EFFECT_FADEIN));
        }

        public void OnDisengageBattleMusic()
        {
            battleMusicSuppressed = true;
            EndBattleMusic();
        }

        // Forgets the push without sending anything: the caller replaces the track itself.
        public void ResetBattleMusic()
        {
            battleMusicSuppressed = false;
            battleMusicActive = false;
            outOfCombatSince = DateTime.MinValue;
        }

        private void UpdateBattleMusic(DateTime tick)
        {
            if (tick < nextBattleMusicCheck)
                return;
            nextBattleMusicCheck = tick.AddSeconds(1);
            if (CurrentArea == null || isZoneChanging || IsDead())
                return;

            bool inCombat = IsInCombat();
            if (battleMusicSuppressed && !inCombat)
                battleMusicSuppressed = false;
            if (!battleMusicActive)
            {
                if (inCombat)
                    StartBattleMusic();
                return;
            }
            if (inCombat)
                outOfCombatSince = DateTime.MinValue;
            else if (outOfCombatSince == DateTime.MinValue)
                outOfCombatSince = tick;
            else if ((tick - outOfCombatSince).TotalSeconds >= BATTLE_MUSIC_END_GRACE_SECONDS)
                EndBattleMusic();
        }




        public void SendMountAppearance()
        {
            if (mountState == 1)
                BroadcastPacket(SetCurrentMountChocoboPacket.BuildPacket(Id, chocoboAppearance, rentalExpireTime, rentalMinLeft), true);
            else if (mountState == 2)
                BroadcastPacket(SetCurrentMountGoobbuePacket.BuildPacket(Id, 1), true);
        }

        public void SetMountState(byte mountState)
        {
            this.mountState = mountState;
            SendMountAppearance();
        }

        public byte GetMountState()
        {
            return mountState;
        }

        public void DoEmote(uint targettedActor, uint animId, uint descId)
        {
            BroadcastPacket(ActorDoEmotePacket.BuildPacket(Id, targettedActor, animId, descId), true);
        }

        public void SendGameMessage(Actor sourceActor, Actor textIdOwner, ushort textId, byte log, params object[] msgParams)
        {
            if (msgParams == null || msgParams.Length == 0)
            {
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, sourceActor.Id, textIdOwner.Id, textId, log));
            }
            else
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, sourceActor.Id, textIdOwner.Id, textId, log, LuaUtils.CreateLuaParamList(msgParams)));
        }

        public void SendGameMessage(Actor textIdOwner, ushort textId, byte log, params object[] msgParams)
        {
            if (msgParams == null || msgParams.Length == 0)
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, log));
            else
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, log, LuaUtils.CreateLuaParamList(msgParams)));
        }

        public void SendGameMessageDisplayName(Actor textIdOwner, ushort textId, byte log, string customSender, params object[] msgParams)
        {
            if (msgParams == null || msgParams.Length == 0)
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, customSender, log));
            else
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, customSender, log, LuaUtils.CreateLuaParamList(msgParams)));
        }

        public void SendGameMessageLocalizedDisplayName(Actor textIdOwner, ushort textId, byte log, uint displayId, params object[] msgParams)
        {
            if (msgParams == null || msgParams.Length == 0)
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, displayId, log));
            else
                QueuePacket(GameMessagePacket.BuildPacket(Server.GetWorldManager().GetActor().Id, textIdOwner.Id, textId, displayId, log, LuaUtils.CreateLuaParamList(msgParams)));
        }

        public void BroadcastWorldMessage(ushort worldMasterId, params object[] msgParams)
        {
            //SubPacket worldMasterMessage = 
            //CurrentArea.BroadcastPacketAroundActor(this, worldMasterMessage);
        }

        public void ChangeIntoNpc(Npc npc)
        {
            uint[] npcAppearIds = new uint[appearanceIds.Length];
            for (int i = 0; i < appearanceIds.Length; i++)
                npcAppearIds[i] = npc.appearanceIds[i];

            SetActorAppearancePacket setappearance = new SetActorAppearancePacket(npc.modelId, npcAppearIds);
            BroadcastPacket(setappearance.BuildPacket(Id), true);
        }

        public void GraphicChange(uint slot, uint graphicId)
        {
            appearanceIds[slot] = graphicId;
        }

        public void GraphicChange(uint slot, uint weapId, uint equipId, uint variantId, uint colorId)
        {

            uint mixedVariantId;

            if (weapId == 0)
                mixedVariantId = ((variantId & 0x1F) << 5) | colorId;
            else
                mixedVariantId = variantId;

            uint graphicId =
                    (weapId & 0x3FF) << 20 |
                    (equipId & 0x3FF) << 10 |
                    (mixedVariantId & 0x3FF);

            appearanceIds[slot] = graphicId;

        }

        public void GraphicChange(int slot, InventoryItem invItem)
        {
            if (invItem == null)
                appearanceIds[slot] = 0;
            else
            {
                ItemData item = Server.GetItemGamedata(invItem.itemId);

                if (item is EquipmentItem)
                {
                    EquipmentItem eqItem = (EquipmentItem)item;

                    uint mixedVariantId;

                    if (eqItem.graphicsWeaponId == 0)
                        mixedVariantId = ((eqItem.graphicsVariantId & 0x1F) << 5) | eqItem.graphicsColorId;
                    else
                        mixedVariantId = eqItem.graphicsVariantId;

                    uint graphicId =
                            (eqItem.graphicsWeaponId & 0x3FF) << 20 |
                            (eqItem.graphicsEquipmentId & 0x3FF) << 10 |
                            (mixedVariantId & 0x3FF);

                    appearanceIds[slot] = graphicId;
                }

                //Handle offhand
                if (slot == MAINHAND && item is WeaponItem nails && nails.IsNailWeapon())
                {
                    appearanceIds[SetActorAppearancePacket.OFFHAND] =
                            ((nails.graphicsWeaponId + 1) & 0x3FF) << 20 |
                            (nails.graphicsEquipmentId & 0x3FF) << 10 |
                            (nails.graphicsVariantId & 0x3FF);
                }
                else if (slot == MAINHAND && item is WeaponItem)
                {
                    WeaponItem wpItem = (WeaponItem)item;

                    uint graphicId =
                            (wpItem.graphicsOffhandWeaponId & 0x3FF) << 20 |
                            (wpItem.graphicsOffhandEquipmentId & 0x3FF) << 10 |
                            (wpItem.graphicsOffhandVariantId & 0x3FF);

                    // A weapon with no offhand look clears the last one (a pugilist's second fist) unless a shield is worn.
                    if (graphicId != 0 || GetEquipment()?.GetItemAtSlot(SLOT_OFFHAND) == null)
                        appearanceIds[SetActorAppearancePacket.OFFHAND] = graphicId;
                }

                //Handle ALC offhand special case
                if (slot == OFFHAND && item is WeaponItem && item.IsAlchemistWeapon())
                {
                    WeaponItem wpItem = (WeaponItem)item;

                    uint graphicId =
                            ((wpItem.graphicsWeaponId + 1) & 0x3FF) << 20 |
                            (wpItem.graphicsEquipmentId & 0x3FF) << 10 |
                            (wpItem.graphicsVariantId & 0x3FF);

                    if (graphicId != 0)
                        appearanceIds[SetActorAppearancePacket.SPOFFHAND] = graphicId;
                }
            }

            Database.SavePlayerAppearance(this);
            BroadcastPacket(CreateAppearancePacket(), true);
        }

        public void SendAppearance()
        {
            BroadcastPacket(CreateAppearancePacket(), true);
        }

        public void SendCharaExpInfo()
        {
            if (lastStep == 0)
            {
                int maxLength;
                if ((sizeof(short) * charaWork.battleSave.skillLevel.Length) - lastPosition < 0x5E)
                    maxLength = (sizeof(short) * charaWork.battleSave.skillLevel.Length) - lastPosition;
                else
                    maxLength = 0x5E;

                byte[] skillLevelBuffer = new byte[maxLength];
                Buffer.BlockCopy(charaWork.battleSave.skillLevel, 0, skillLevelBuffer, 0, skillLevelBuffer.Length);
                SetActorPropetyPacket charaInfo1 = new SetActorPropetyPacket("charaWork/exp");

                charaInfo1.SetIsArrayMode(true);
                if (maxLength == 0x5E)
                {
                    charaInfo1.AddBuffer(Utils.MurmurHash2("charaWork.battleSave.skillLevel", 0), skillLevelBuffer, 0, skillLevelBuffer.Length, 0x0);
                    lastPosition += maxLength;
                }
                else
                {
                    charaInfo1.AddBuffer(Utils.MurmurHash2("charaWork.battleSave.skillLevel", 0), skillLevelBuffer, 0, skillLevelBuffer.Length, 0x3);
                    lastPosition = 0;
                    lastStep++;
                }

                charaInfo1.AddTarget();

                QueuePacket(charaInfo1.BuildPacket(Id));
            }
            else if (lastStep == 1)
            {
                int maxLength;
                if ((sizeof(short) * charaWork.battleSave.skillLevelCap.Length) - lastPosition < 0x5E)
                    maxLength = (sizeof(short) * charaWork.battleSave.skillLevelCap.Length) - lastPosition;
                else
                    maxLength = 0x5E;

                byte[] skillCapBuffer = new byte[maxLength];
                Buffer.BlockCopy(charaWork.battleSave.skillLevelCap, lastPosition, skillCapBuffer, 0, skillCapBuffer.Length);
                SetActorPropetyPacket charaInfo1 = new SetActorPropetyPacket("charaWork/exp");


                if (maxLength == 0x5E)
                {
                    charaInfo1.SetIsArrayMode(true);
                    charaInfo1.AddBuffer(Utils.MurmurHash2("charaWork.battleSave.skillLevelCap", 0), skillCapBuffer, 0, skillCapBuffer.Length, 0x1);
                    lastPosition += maxLength;
                }
                else
                {
                    charaInfo1.SetIsArrayMode(false);
                    charaInfo1.AddBuffer(Utils.MurmurHash2("charaWork.battleSave.skillLevelCap", 0), skillCapBuffer, 0, skillCapBuffer.Length, 0x3);
                    lastStep = 0;
                    lastPosition = 0;
                }

                charaInfo1.AddTarget();

                QueuePacket(charaInfo1.BuildPacket(Id));
            }

        }

        private void SendAchievedAetheryte(ushort from, ushort to)
        {
            Bitstream fakeAetheryte = new Bitstream(512, true);

            SetActorPropetyPacket completedQuestWorkUpdate = new SetActorPropetyPacket(from, to, "work/achieveAetheryte");
            completedQuestWorkUpdate.AddBitfield(Utils.MurmurHash2("work.event_achieve_aetheryte", 0), fakeAetheryte.GetSlice(from, to));
            completedQuestWorkUpdate.AddTarget();
            QueuePacket(completedQuestWorkUpdate.BuildPacket(Id));
        }

        private void SendCompletedQuests(ushort from, ushort to)
        {
            byte[] data = questStateManager.GetCompletionSliceBytes(from, to);

            SetActorPropetyPacket completedQuestWorkUpdate = new SetActorPropetyPacket(from, to, "playerWork/journal");
            completedQuestWorkUpdate.AddBitfield(Utils.MurmurHash2("playerWork.questScenarioComplete", 0), data);
            completedQuestWorkUpdate.AddTarget();
            QueuePacket(completedQuestWorkUpdate.BuildPacket(Id));
        }

        // playerWork.questGuildleveComplete, index questId - 120001.
        private void SendCompletedGuildleveQuests(ushort from, ushort to)
        {
            byte[] data = new Bitstream(playerWork.questGuildleveComplete).GetSlice(from, to);

            SetActorPropetyPacket completedQuestWorkUpdate = new SetActorPropetyPacket(from, to, "playerWork/questCompleteG");
            completedQuestWorkUpdate.AddBitfield(Utils.MurmurHash2("playerWork.questGuildleveComplete", 0), data);
            completedQuestWorkUpdate.AddTarget();
            QueuePacket(completedQuestWorkUpdate.BuildPacket(Id));
        }

        public void OnWorkSyncRequest(string propertyName, ushort from = 0, ushort to = 0)
        {
            switch (propertyName)
            {
                case "charaWork/exp":
                    SendCharaExpInfo();
                    break;
                case "work/achieveAetheryte":
                    SendAchievedAetheryte(from, to);
                    break;
                case "playerWork/questCompleteS":
                    SendCompletedQuests(from, to);
                    break;
                case "playerWork/questCompleteG":
                    SendCompletedGuildleveQuests(from, to);
                    break;
            }
        }

        public int GetHighestLevel()
        {
            int max = 0;
            foreach (short level in charaWork.battleSave.skillLevel)
            {
                if (level > max)
                    max = level;
            }
            return max;
        }

        public InventoryItem[] GetGearset(ushort classId)
        {
            return Database.GetEquipment(this, classId);
        }

        public void PrepareClassChange(byte classId)
        {
            SendCharaExpInfo();
        }

        public void DoClassChange(byte classId)
        {
            //load hotbars
            //Calculate stats
            //Calculate hp/mp

            //Get Potenciel ??????

            //Set HP/MP/TP PARAMS

            //Set mainskill and level

            //Set Parameters

            //Set current EXP

            //Set Hotbar Commands 1
            //Set Hotbar Commands 2
            //Set Hotbar Commands 3

            //Check if bonus point available... set

            //Remove buffs that fall off when changing class
            CommandResultContainer resultContainer = new CommandResultContainer();
            statusEffects.RemoveStatusEffectsByFlags((uint)StatusEffectFlags.LoseOnClassChange, resultContainer);
            resultContainer.CombineLists();
            DoBattleAction(0, 0x7c000062, resultContainer.GetList());

            //If new class, init abilties and level
            if (charaWork.battleSave.skillLevel[classId - 1] <= 0)
            {
                UpdateClassLevel(classId, 1);
                EquipAbilitiesAtLevel(classId, 1);
            }

            //Set rested EXP
            charaWork.parameterSave.state_mainSkill[0] = classId;
            charaWork.parameterSave.state_mainSkillLevel = charaWork.battleSave.skillLevel[classId - 1];
            playerWork.restBonusExpRate = GetRestBonusExpRate();

            if (currentJob != 0 && ConvertClassIdToJobId(classId) != currentJob)
            {
                currentJob = 0;
                BroadcastPacket(SetCurrentJobPacket.BuildPacket(Id, 0), true);
            }
            for (int i = charaWork.commandBorder; i < charaWork.command.Length; i++)
            {
                charaWork.command[i] = 0;
                charaWork.commandCategory[i] = 0;
            }

            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("charaWork/stateForAll", this);

            propertyBuilder.AddProperty("charaWork.parameterSave.state_mainSkill[0]");
            propertyBuilder.AddProperty("charaWork.parameterSave.state_mainSkillLevel");
            propertyBuilder.NewTarget("playerWork/expBonus");
            propertyBuilder.AddProperty("playerWork.restBonusExpRate");
            propertyBuilder.NewTarget("charaWork/battleStateForSelf");
            propertyBuilder.AddProperty(String.Format("charaWork.battleSave.skillPoint[{0}]", classId - 1));
            Database.LoadHotbar(this);

            var time = Utils.UnixTimeStampUTC();
            for (int i = charaWork.commandBorder; i < charaWork.command.Length; i++)
            {
                if (charaWork.command[i] != 0)
                {
                    charaWork.parameterSave.commandSlot_recastTime[i - charaWork.commandBorder] = time + charaWork.parameterTemp.maxCommandRecastTime[i - charaWork.commandBorder];
                }
            }

            UpdateHotbar();

            List<SubPacket> packets = propertyBuilder.Done();

            foreach (SubPacket packet in packets)
                BroadcastPacket(packet, true);

            Database.SavePlayerCurrentClass(this);
            CalculateBaseStats();
            questStateManager.UpdateLevel(GetLevel());
        }

        public void UpdateClassLevel(byte classId, short level)
        {
            Database.PlayerCharacterUpdateClassLevel(this, classId, level);
            charaWork.battleSave.skillLevel[classId - 1] = level;
            ActorPropertyPacketUtil propertyBuilder = new ActorPropertyPacketUtil("charaWork/stateForAll", this);
            propertyBuilder.AddProperty(String.Format("charaWork.battleSave.skillLevel[{0}]", classId - 1));
            List<SubPacket> packets = propertyBuilder.Done();
            QueuePackets(packets);
        }

        public void SetRepairRequest(byte type)
        {
            charaWork.eventSave.repairType = type;
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("charaWork/bazaar", this);
            propPacketUtil.AddProperty("charaWork.eventSave.repairType");
            QueuePackets(propPacketUtil.Done());
        }

        public void CheckBazaarFlags(bool noUpdate = false)
        {
            bool isDealing = false, isRepairing = false, seekingItem = false;
            lock (GetItemPackage(ItemPackage.BAZAAR))
            {
                foreach (InventoryItem item in GetItemPackage(ItemPackage.BAZAAR).GetRawList())
                {
                    if (item == null)
                        break;

                    if (item.GetBazaarMode() == InventoryItem.MODE_SELL_SINGLE || item.GetBazaarMode() == InventoryItem.MODE_SELL_PSTACK || item.GetBazaarMode() == InventoryItem.MODE_SELL_FSTACK)
                        isDealing = true;
                    if (item.GetBazaarMode() == InventoryItem.MODE_SEEK_REPAIR)
                        isRepairing = true;
                    if (item.GetBazaarMode() == InventoryItem.MODE_SEEK_ITEM)
                        isDealing = true;

                    if (isDealing && isRepairing && seekingItem)
                        break;
                }
            }

            bool doUpdate = false;

            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("charaWork/bazaar", this);
            if (charaWork.eventTemp.bazaarRetail != isDealing)
            {
                charaWork.eventTemp.bazaarRetail = isDealing;
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarRetail");
                doUpdate = true;
            }

            if (charaWork.eventTemp.bazaarRepair != isRepairing)
            {
                charaWork.eventTemp.bazaarRepair = isRepairing;
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarRepair");
                doUpdate = true;
            }

            if (charaWork.eventTemp.bazaarMateria != (GetItemPackage(ItemPackage.MELDREQUEST).GetCount() != 0))
            {
                charaWork.eventTemp.bazaarMateria = GetItemPackage(ItemPackage.MELDREQUEST).GetCount() != 0;
                propPacketUtil.AddProperty("charaWork.eventTemp.bazaarMateria");
                doUpdate = true;
            }

            if (!noUpdate && doUpdate)
                BroadcastPackets(propPacketUtil.Done(), true);
        }

        public int GetCurrentGil()
        {
            if (HasItem(1000001))
                return GetItemPackage(ItemPackage.CURRENCY_CRYSTALS).GetItemByCatelogId(1000001).quantity;
            else
                return 0;
        }

        public Actor GetActorInInstance(uint actorId)
        {
            foreach (Actor a in playerSession.actorInstanceList)
            {
                if (a.Id == actorId)
                    return a;
            }

            return null;
        }

        public void SetZoneChanging(bool flag)
        {
            isZoneChanging = flag;
            if (flag)
                return;
            // A warp can put the player in one half of a city at a spot that belongs to the other.
            seamlessCheckPending = true;
            // The zone-in bundle had the state from when it was built; a revive during loading (Return)
            // never reached the client. A death to replay waits a moment for the client to settle.
            if (pendingDeathReplay)
                deathReplayAt = DateTime.Now.AddSeconds(1.5);
            else
                updateFlags |= ActorUpdateFlags.State | ActorUpdateFlags.HpTpMp;
        }

        public bool IsInZoneChange()
        {
            return isZoneChanging;
        }

        public ReferencedItemPackage GetEquipment()
        {
            return equipment;
        }

        public byte GetInitialTown()
        {
            return playerWork.initialTown;
        }

        public uint GetHomePoint()
        {
            return homepoint;
        }

        public List<Recipe> GetRecentRecipes()
        {
            return recentRecipes;
        }

        public List<Recipe> GetAwardedRecipes()
        {
            return awardedRecipes;
        }

        public void AddRecentRecipe(Recipe recipe)
        {
            AddToRecipeList(recentRecipes, recipe);
        }

        public void AddAwardedRecipe(Recipe recipe)
        {
            AddToRecipeList(awardedRecipes, recipe);
        }

        private static void AddToRecipeList(List<Recipe> list, Recipe recipe)
        {
            if (recipe == null)
                return;
            list.Remove(recipe);
            list.Insert(0, recipe);
            if (list.Count > MAX_RECIPE_LIST)
                list.RemoveAt(MAX_RECIPE_LIST);
        }

        public byte GetHomePointInn()
        {
            return homepointInn;
        }

        public void SetHomePoint(uint aetheryteId)
        {
            homepoint = aetheryteId;
            Database.SavePlayerHomePoints(this);
        }

        public void SetHomePointInn(byte townId)
        {
            homepointInn = townId;
            Database.SavePlayerHomePoints(this);
        }

        public ushort GetGMLevel()
        {
            return gmLevel;
        }

        public void SetGMLevel(ushort level)
        {
            gmLevel = level;
            Database.SetGmLevel(this, level);
            SetDCFlag(false); // re-sends the GM icon
        }

        public bool HasAetheryteNodeUnlocked(uint aetheryteId)
        {
            if (aetheryteId != 0)
                return true;
            else
                return false;
        }

        public int GetFreeQuestSlot()
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] == null)
                    return i;
            }

            return -1;
        }

        // work.guildleveId[16]: slots 0-7 hold regional/faction leve ids, slots 8-15 hold local
        // leves as (questId - 120000), mirrored by playerWork.questGuildleve[0-7] = 0xA0F00000 | questId.
        public const int REGIONAL_GUILDLEVE_SLOTS = 8;
        public const int LOCAL_GUILDLEVE_FIRST_SLOT = 8;
        public const uint LOCAL_GUILDLEVE_ID_BASE = 120000;

        public static bool IsLocalGuildleveId(uint id)
        {
            return id > LOCAL_GUILDLEVE_ID_BASE && id < LOCAL_GUILDLEVE_ID_BASE + 10000;
        }

        // Free regional slot (0-7), or -1.
        public int GetFreeGuildleveSlot()
        {
            for (int i = 0; i < REGIONAL_GUILDLEVE_SLOTS; i++)
            {
                if (work.guildleveId[i] == 0)
                    return i;
            }

            return -1;
        }

        // Free local slot as an index into playerWork.questGuildleve (0-7), or -1.
        public int GetFreeLocalGuildleveSlot()
        {
            for (int i = 0; i < playerWork.questGuildleve.Length; i++)
            {
                if (playerWork.questGuildleve[i] == 0 && work.guildleveId[LOCAL_GUILDLEVE_FIRST_SLOT + i] == 0)
                    return i;
            }

            return -1;
        }

        // work.guildleveId slot holding this leve (regional 0-7, local 8-15), or -1.
        public int GetGuildleveWorkSlot(uint id)
        {
            if (IsLocalGuildleveId(id))
            {
                ushort stored = (ushort)(id - LOCAL_GUILDLEVE_ID_BASE);
                for (int i = LOCAL_GUILDLEVE_FIRST_SLOT; i < work.guildleveId.Length; i++)
                {
                    if (work.guildleveId[i] == stored)
                        return i;
                }
            }
            else if (id != 0)
            {
                for (int i = 0; i < REGIONAL_GUILDLEVE_SLOTS; i++)
                {
                    if (work.guildleveId[i] == id)
                        return i;
                }
            }

            return -1;
        }

        #region Quests - Script Related
        // Add quest from an active quest in the player's quest state. Quest scripts will use this to add a quest.
        public bool AcceptQuest(Quest instance, bool isSilent = false)
        {
            if (instance == null)
                return false;

            int freeSlot = GetFreeQuestSlot();

            if (freeSlot == -1)
            {
                SendGameMessage(Server.GetWorldManager().GetActor(), 25234, 0x20); // "You cannot accept any more quests at this time."
                return false;
            }

            playerWork.questScenario[freeSlot] = instance.Id;
            questScenario[freeSlot] = instance;
            SendQuestClientUpdate(freeSlot);

            if (!isSilent)
            {
                WorldMaster worldMaster = Server.GetWorldManager().GetActor();
                SendDataPacket("attention", worldMaster, "", 25224, (object)questScenario[freeSlot].GetQuestId()); // "<Quest> accepted."
                SendGameMessage(worldMaster, 25224, 0x20, (object)questScenario[freeSlot].GetQuestId()); // "<Quest> accepted."
            }

            instance.OnAccept();

            Database.SaveQuest(this, questScenario[freeSlot], freeSlot);

            return true;
        }

        // Replace a quest with another quest in the player's quest state.
        public void ReplaceQuest(Quest oldQuestInstance, string questName)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Equals(oldQuestInstance))
                {
                    SendQuestClientUpdate(i);
                    GrantQuestRewards(oldQuestInstance.GetQuestId());
                    oldQuestInstance.OnComplete();
                    playerWork.questScenarioComplete[oldQuestInstance.GetQuestId() - 110001] = true;
                    Database.SaveCompletedQuests(playerSession.GetActor());
                    questStateManager.UpdateQuestCompleted(oldQuestInstance);
                    Quest newQuestInstance = questStateManager.GetActiveQuest(((Quest)Server.GetStaticActors(questName)).GetQuestId());
                    questScenario[i] = newQuestInstance;
                    playerWork.questScenario[i] = questScenario[i].Id;
                    newQuestInstance.OnAccept();
                    Database.SaveQuest(this, questScenario[i], i);
                    break;
                }
            }
        }

        public void CompleteQuest(Quest completed)
        {
            CompleteQuest(completed, 1);
        }

        // tier 2+ picks the reward sheet's higher amounts.
        public void CompleteQuest(Quest completed, int tier)
        {
            int slot = GetQuestSlot(completed);
            if (slot >= 0)
            {
                // Remove the quest from the DB and update client work values
                playerWork.questScenarioComplete[completed.GetQuestId() - 110001] = true;
                questScenario[slot] = null;
                playerWork.questScenario[slot] = 0;
                SendQuestClientUpdate(slot);

                GrantQuestRewards(completed.GetQuestId(), tier);

                // Reset active quest and quest state
                completed.OnComplete();
                Database.SaveCompletedQuests(playerSession.GetActor());
                Database.RemoveQuest(this, completed.Id);
                questStateManager.UpdateQuestCompleted(completed);

                // Msg Player
                SendGameMessage(Server.GetWorldManager().GetActor(), 25086, 0x20, (object)completed.GetQuestId()); // "<Quest> complete!"
            }

        }

        public bool AbandonQuest(uint questId)
        {
            // Check if in an instance
            if (CurrentArea.IsPrivate())
            {
                SendGameMessage(Server.GetWorldManager().GetActor(), 25235, 0x20); // "Quests cannot be abandoned while from within an instance."
                return false;
            }

            // Get the quest object
            int slot = GetQuestSlot(questId);
            Quest abandoned = questScenario[slot];

            if (abandoned == null)
                return false;

            // Check if Main Scenario
            if (abandoned.IsMainScenario())
            {
                SendGameMessage(Server.GetWorldManager().GetActor(), 25233, 0x20); // "Main scenario quests cannot be abandoned."
                return false;
            }

            // Remove the quest from the DB and update client work values
            questScenario[slot] = null;
            playerWork.questScenario[slot] = 0;
            SendQuestClientUpdate(slot);

            // Reset active quest and quest state
            abandoned.OnAbandon();
            Database.RemoveQuest(this, abandoned.Id);
            questStateManager.UpdateQuestAbandoned();

            // Msg Player
            SendGameMessage(this, Server.GetWorldManager().GetActor(), 25236, 0x20, (object)abandoned.GetQuestId()); // "<Quest> abandoned."
            return true;
        }

        public bool HasQuest(Quest questInstance)
        {
            return GetQuestSlot(questInstance) != -1;
        }
        #endregion

        #region Quests - Debug/Misc Related
        // Force-Add a quest by Id. Called be debug scripts.
        public void AddQuest(int id, bool isSilent = false)
        {
            Actor actor = Server.GetStaticActors((0xA0F00000 | (uint)id));
            AddQuest(actor.Name, isSilent);
        }

        // Force-Add a quest by Name. Called be debug scripts. Will try to use an active quest, otherwise adds a new instance.
        public void AddQuest(string name, bool isSilent = false)
        {
            Quest baseQuest = (Quest)Server.GetStaticActors(name);
            Quest activeQuest = questStateManager.GetActiveQuest(baseQuest.GetQuestId());

            int freeSlot = GetFreeQuestSlot();

            if (freeSlot == -1)
                return;

            playerWork.questScenario[freeSlot] = baseQuest.Id;
            questScenario[freeSlot] = activeQuest ?? new Quest(this, baseQuest);

            if (activeQuest == null)
                questStateManager.ForceAddActiveQuest(questScenario[freeSlot]);

            SendQuestClientUpdate(freeSlot);

            if (!isSilent)
            {
                SendGameMessage(Server.GetWorldManager().GetActor(), 25224, 0x20, (object)questScenario[freeSlot].GetQuestId());
            }

            questScenario[freeSlot].OnAccept();

            Database.SaveQuest(this, questScenario[freeSlot], freeSlot);
        }

        public void RemoveQuest(int id)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Id == (0xA0F00000 | id))
                {
                    Database.RemoveQuest(this, questScenario[i].Id);
                    questScenario[i] = null;
                    playerWork.questScenario[i] = 0;
                    questStateManager.UpdateQuestAbandoned();
                    SendQuestClientUpdate(i);
                    break;
                }
            }
        }

        public void RemoveQuest(string name)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Name.ToLower().Equals(name.ToLower()))
                {
                    Database.RemoveQuest(this, questScenario[i].Id);
                    questScenario[i] = null;
                    playerWork.questScenario[i] = 0;
                    questStateManager.UpdateQuestAbandoned();
                    SendQuestClientUpdate(i);
                    break;
                }
            }
        }

        public bool HasQuest(string name)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Name.ToLower().Equals(name.ToLower()))
                    return true;
            }

            return false;
        }

        public bool HasQuest(uint id)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Id == (0xA0F00000 | id))
                    return true;
            }

            return false;
        }

        public bool IsQuestCompleted(uint id)
        {
            return questStateManager.IsQuestComplete(id);
        }

        public void SetQuestComplete(uint id, bool flag)
        {
            if (flag)
            {
                Quest currentQuest = GetQuest(id);
                if (currentQuest != null)
                {
                    CompleteQuest(currentQuest);
                    return;
                }
            }
            questStateManager.ForceQuestCompleteFlag(id, flag);
        }

        public Quest GetQuest(uint id)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Id == (0xA0F00000 | id))
                    return questScenario[i];
            }

            return null;
        }

        public Quest GetQuest(string name)
        {
            for (int i = 0; i < questScenario.Length; i++)
            {
                if (questScenario[i] != null && questScenario[i].Name.ToLower().Equals(name.ToLower()))
                    return questScenario[i];
            }

            return null;
        }

        public int GetQuestSlot(Quest quest)
        {
            for (int slot = 0; slot < questScenario.Length; slot++)
            {
                if (questScenario[slot] != null && questScenario[slot].Id == quest.Id)
                    return slot;
            }

            return -1;
        }

        public int GetQuestSlot(uint id)
        {
            for (int slot = 0; slot < questScenario.Length; slot++)
            {
                if (questScenario[slot] != null && questScenario[slot].GetQuestId() == id)
                    return slot;
            }

            return -1;
        }
        #endregion

        #region SNpc Functions (Path Companion)
        public void SetSNpc(string nickname, uint actorClassId, byte classType)
        {
            // Set name and appearance
            SNpcNickname = nickname;
            SNpcSkin = (byte)(actorClassId - 1070000);

            switch (SNpcSkin % 16)
            {
                // Hyur Male
                case 1:
                    SNpcPersonality = 1;
                    break;
                // Hyur Female
                case 2:
                case 16:
                    SNpcPersonality = 2;
                    break;
                // Elezen Male
                case 3:
                case 4:
                    SNpcPersonality = 3;
                    break;
                // Elezen Female
                case 5:
                case 6:
                    SNpcPersonality = 4;
                    break;
                // Lalafel Male
                case 7:
                case 8:
                    SNpcPersonality = 5;
                    break;
                // Lalafel Female
                case 9:
                case 10:
                    SNpcPersonality = 6;
                    break;
                // Miqo'te
                case 11:
                case 12:
                    SNpcPersonality = 8;
                    break;
                // Roegadyn
                case 13:
                case 14:
                    SNpcPersonality = 7;
                    break;
                // Highlander
                case 15:
                    SNpcPersonality = 9;
                    break;
            }

            // Save to DB
            Database.CreateOrUpdateSNpc(this, SNpcNickname, SNpcSkin, SNpcPersonality);
        }

        public string GetSNpcNickname()
        {
            return SNpcNickname ?? "???";
        }

        public byte GetSNpcSkin()
        {
            return SNpcSkin;
        }

        public byte GetSNpcPersonality()
        {
            return SNpcPersonality;
        }

        public short GetSNpcCoordinate()
        {
            return SNpcCoordinate;
        }
        #endregion

        #region Guildleves
        public void AddGuildleve(uint id)
        {
            if (IsLocalGuildleveId(id))
            {
                AddLocalGuildleve(id);
                return;
            }

            int freeSlot = GetFreeGuildleveSlot();

            if (freeSlot == -1)
                return;

            work.guildleveId[freeSlot] = (ushort)id;
            work.guildleveDone[freeSlot] = false;
            work.guildleveChecked[freeSlot] = false;
            Database.SaveGuildleve(this, id, freeSlot);
            SendGuildleveClientUpdate(freeSlot);
        }

        // Local (passive) leve: playerWork.questGuildleve[n] = 0xA0F00000 | questId and
        // work.guildleveId[8 + n] = questId - 120000.
        public void AddLocalGuildleve(uint questId)
        {
            AddLocalGuildleve(questId, 0);
        }

        public void AddLocalGuildleve(uint questId, byte difficulty)
        {
            if (!IsLocalGuildleveId(questId) || HasGuildleve(questId))
                return;

            int localSlot = GetFreeLocalGuildleveSlot();
            if (localSlot == -1)
                return;

            int workSlot = LOCAL_GUILDLEVE_FIRST_SLOT + localSlot;
            playerWork.questGuildleve[localSlot] = 0xA0F00000 | questId;
            work.guildleveId[workSlot] = (ushort)(questId - LOCAL_GUILDLEVE_ID_BASE);
            work.guildleveDone[workSlot] = false;
            work.guildleveChecked[workSlot] = false;
            Database.SaveLocalGuildleve(this, questId, localSlot);
            passiveGuildleves[localSlot] = PassiveGuildleve.Create(this, questId, difficulty);
            passiveGuildleves[localSlot]?.SaveData();
            SendLocalGuildleveClientUpdate(localSlot);
        }

        // Takes a local leve at a difficulty (0-3).
        public void AddQuestGuildleve(uint id, byte difficulty)
        {
            AddLocalGuildleve(id, difficulty);
        }

        public PassiveGuildleve GetQuestGuildleve(uint id)
        {
            int slot = GetQuestGuildleveSlot(id);
            return slot == -1 ? null : passiveGuildleves[slot];
        }

        public bool HasQuestGuildleve(uint id)
        {
            return GetQuestGuildleveSlot(id) != -1;
        }

        // Index into playerWork.questGuildleve (0-7) holding this local leve, or -1.
        public int GetQuestGuildleveSlot(uint id)
        {
            uint actorId = 0xA0F00000 | (id & 0xFFFFF);
            for (int i = 0; i < playerWork.questGuildleve.Length; i++)
            {
                if (playerWork.questGuildleve[i] == actorId)
                    return i;
            }
            return -1;
        }

        // The journal reads (done, checked) as 0 0 retained, 0 1 active, 1 0 failed, 1 1 completed.
        // The DB columns "abandoned"/"completed" hold done/checked.
        public void SetGuildleveState(uint id, bool done, bool isChecked)
        {
            int slot = GetGuildleveWorkSlot(id);
            if (slot == -1)
                return;

            work.guildleveDone[slot] = done;
            work.guildleveChecked[slot] = isChecked;
            if (slot >= LOCAL_GUILDLEVE_FIRST_SLOT)
                Database.MarkLocalGuildleve(this, id, done, isChecked);
            else
                Database.MarkGuildleve(this, id, done, isChecked);
            SendGuildleveMarkClientUpdate(slot);
        }

        public void SetGuildleveRetained(uint id) { SetGuildleveState(id, false, false); }
        public void SetGuildleveActive(uint id) { SetGuildleveState(id, false, true); }
        public void SetGuildleveFailed(uint id) { SetGuildleveState(id, true, false); }
        public void SetGuildleveCompleted(uint id) { SetGuildleveState(id, true, true); }

        public bool IsGuildleveFailed(uint id)
        {
            int slot = GetGuildleveWorkSlot(id);
            return slot != -1 && work.guildleveDone[slot] && !work.guildleveChecked[slot];
        }

        // Kept for scripts: "abandoned" is the done bit and "completed" the checked bit.
        public void MarkGuildleve(uint id, bool abandoned, bool completed)
        {
            SetGuildleveState(id, abandoned, completed);
        }

        // The journal lists leves only up to the first empty slot, so the ones after a removed leve move up.
        public void RemoveGuildleve(uint id)
        {
            int slot = GetGuildleveWorkSlot(id);
            if (slot == -1)
                return;

            bool isLocal = slot >= LOCAL_GUILDLEVE_FIRST_SLOT;
            int first = isLocal ? LOCAL_GUILDLEVE_FIRST_SLOT : 0;
            int last = isLocal ? work.guildleveId.Length - 1 : LOCAL_GUILDLEVE_FIRST_SLOT - 1;

            if (isLocal)
                Database.RemoveLocalGuildleve(this, id);
            else
                Database.RemoveGuildleve(this, id);

            for (int s = slot; s < last; s++)
            {
                work.guildleveId[s] = work.guildleveId[s + 1];
                work.guildleveDone[s] = work.guildleveDone[s + 1];
                work.guildleveChecked[s] = work.guildleveChecked[s + 1];
                if (isLocal)
                {
                    int l = s - first;
                    playerWork.questGuildleve[l] = playerWork.questGuildleve[l + 1];
                    passiveGuildleves[l] = passiveGuildleves[l + 1];
                }
                if (work.guildleveId[s] != 0)
                    Database.SetGuildleveSlot(this, isLocal ? work.guildleveId[s] + LOCAL_GUILDLEVE_ID_BASE : work.guildleveId[s], s - first, isLocal);
            }
            work.guildleveId[last] = 0;
            work.guildleveDone[last] = false;
            work.guildleveChecked[last] = false;
            if (isLocal)
            {
                playerWork.questGuildleve[last - first] = 0;
                passiveGuildleves[last - first] = null;
            }

            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("work/guildleve", this);
            for (int s = slot; s <= last; s++)
            {
                propPacketUtil.AddProperty(String.Format("work.guildleveId[{0}]", s));
                propPacketUtil.AddProperty(String.Format("work.guildleveDone[{0}]", s));
                propPacketUtil.AddProperty(String.Format("work.guildleveChecked[{0}]", s));
            }
            if (isLocal)
            {
                propPacketUtil.NewTarget("playerWork/journal");
                for (int s = slot; s <= last; s++)
                    propPacketUtil.AddProperty(String.Format("playerWork.questGuildleve[{0}]", s - first));
            }
            QueuePackets(propPacketUtil.Done());
        }

        public bool HasGuildleve(uint id)
        {
            return GetGuildleveWorkSlot(id) != -1;
        }
        #endregion

        public Quest GetDefaultTalkQuest(Npc npc)
        {
            Quest defaultTalk = null;

            switch (npc.CurrentArea.RegionId)
            {
                case 101:
                    defaultTalk = (Quest)Server.GetStaticActors("DftSea");
                    break;
                case 102:
                    defaultTalk = (Quest)Server.GetStaticActors("DftRoc");
                    break;
                case 103:
                    defaultTalk = (Quest)Server.GetStaticActors("DftFst");
                    break;
                case 104:
                case 107:
                    defaultTalk = (Quest)Server.GetStaticActors("DftWil");
                    break;
                case 105:
                    defaultTalk = (Quest)Server.GetStaticActors("DftLak");
                    break;
                case 805:
                    defaultTalk = (Quest)Server.GetStaticActors("DftSrt");
                    break;
            }

            if (npc.CurrentArea is actors.area.PrivateArea pa && pa.GetPrivateAreaName() == "PrivateAreaMasterPast")
                return null;

            if (defaultTalk != null && defaultTalk.IsQuestENPCByScript(this, npc))
                return defaultTalk;

            return null;
        }

        public Quest GetTutorialQuest(Npc npc)
        {
            if (npc.CurrentArea.RegionId == 101 || npc.CurrentArea.RegionId == 103 || npc.CurrentArea.RegionId == 104)
            {
                switch (npc.GetActorClassId())
                {
                    case 1000137:
                        return (Quest)Server.GetStaticActors("Trl0l1");
                    case 1000230:
                        return (Quest)Server.GetStaticActors("Trl0g1");
                    case 1000841:
                        return (Quest)Server.GetStaticActors("Trl0u1");
                }
            }
            return null;
        }

        public Quest GetQuestDeclaring(string globalName)
        {
            Quest found = null;
            foreach (Quest quest in questScenario)
            {
                if (quest == null || (found != null && quest.GetQuestId() > found.GetQuestId()))
                    continue;
                if (LuaEngine.GetInstance().ScriptDeclares(quest, globalName))
                    found = quest;
            }
            return found;
        }

        public Quest[] GetQuestsForNpc(Npc npc)
        {
            return GetQuestsForNpcEvent(npc, QuestNpcRouting.EVENT_ANY);
        }

        // The held quests that declare this npc's class, the one that owns the spawn first, so a class
        // several quests arm (a shared push trigger, the Path companion) reaches the right quest.
        public Quest[] GetQuestsForNpcEvent(Npc npc, int eventType)
        {
            Quest[] quests = questStateManager.GetQuestsForNpc(npc, CurrentArea.IsPrivate());
            Array.Sort(quests, (q1, q2) => (q1.HasData() ? 1 : 0) - (q2.HasData() ? 1 : 0));
            if (quests.Length < 2)
                return quests;
            return QuestNpcRouting.Order(quests, q => QuestNpcRouting.Score(
                OwnsByGate(q, npc), QuestNpcRouting.OwnsByName(q.Name, npc.GetUniqueId()),
                IsEventEnabled(q, npc, eventType))).ToArray();
        }

        private static bool OwnsByGate(Quest quest, Npc npc)
        {
            if (npc.questGates == null)
                return false;
            foreach (QuestGate gate in npc.questGates)
                if (gate.questId == quest.GetQuestId() && gate.Admits(quest.GetSequence()))
                    return true;
            return false;
        }

        private static bool IsEventEnabled(Quest quest, Npc npc, int eventType)
        {
            QuestState.QuestENpc enpc = quest.GetQuestState()?.GetENpc(npc.GetActorClassId());
            if (enpc == null)
                return false;
            switch (eventType)
            {
                case QuestNpcRouting.EVENT_TALK: return enpc.isTalkEnabled;
                case QuestNpcRouting.EVENT_PUSH: return enpc.isPushEnabled;
                case QuestNpcRouting.EVENT_EMOTE: return enpc.isEmoteEnabled;
                default: return false;
            }
        }

        public void ForceQuestStateUpdate()
        {
            questStateManager.ForceQuestStateUpdate();
        }

        public void HandleBNpcKill(uint bnpcClassId)
        {
            foreach (Quest quest in questScenario)
            {
                if (quest != null)
                    quest.OnKillBNpc(this, bnpcClassId);
            }
        }

        public bool HandleNpcLs(uint id)
        {
            foreach (Quest quest in questScenario)
            {
                if (quest != null && quest.HasNpcLsMsgs(id))
                {
                    quest.OnNpcLs(this);
                    return true;
                }
            }
            return false;
        }

        public void AddNpcLs(uint npcLsId)
        {
            if (playerWork.npcLinkshellChatExtra[npcLsId - 1] == false && playerWork.npcLinkshellChatCalling[npcLsId - 1] == false)
            {
                SetNpcLs(npcLsId, NPCLS_INACTIVE);
                SendGameMessage(Server.GetWorldManager().GetActor(), 25118, 0x20, npcLsId); // "<NpcLs> linkpearl obtained."
            }
        }

        public bool HasNpcLs(uint npcLsId)
        {
            return !(playerWork.npcLinkshellChatExtra[npcLsId - 1] == false && playerWork.npcLinkshellChatCalling[npcLsId - 1] == false);
        }

        public void SetNpcLs(uint npcLsId, uint state)
        {
            bool isCalling, isExtra;
            isCalling = isExtra = false;

            if (npcLsId < 1 || npcLsId > 40)
                return;

            npcLsId--;

            switch (state)
            {
                case NPCLS_INACTIVE:

                    if (playerWork.npcLinkshellChatExtra[npcLsId] == true && playerWork.npcLinkshellChatCalling[npcLsId] == false)
                        return;

                    isExtra = true;
                    break;
                case NPCLS_ACTIVE:

                    if (playerWork.npcLinkshellChatExtra[npcLsId] == false && playerWork.npcLinkshellChatCalling[npcLsId] == true)
                        return;

                    isCalling = true;
                    break;
                case NPCLS_ALERT:

                    if (playerWork.npcLinkshellChatExtra[npcLsId] == true && playerWork.npcLinkshellChatCalling[npcLsId] == true)
                        return;

                    isExtra = isCalling = true;
                    break;
            }

            playerWork.npcLinkshellChatExtra[npcLsId] = isExtra;
            playerWork.npcLinkshellChatCalling[npcLsId] = isCalling;

            Database.SaveNpcLS(this, npcLsId, isCalling, isExtra);

            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("playerWork/npcLinkshellChat", this);
            propPacketUtil.AddProperty(String.Format("playerWork.npcLinkshellChatExtra[{0}]", npcLsId));
            propPacketUtil.AddProperty(String.Format("playerWork.npcLinkshellChatCalling[{0}]", npcLsId));
            QueuePackets(propPacketUtil.Done());
        }

        private void SendQuestClientUpdate(int slot)
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("playerWork/journal", this);
            propPacketUtil.AddProperty(String.Format("playerWork.questScenario[{0}]", slot));
            QueuePackets(propPacketUtil.Done());
        }

        private void SendGuildleveClientUpdate(int slot)
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("work/guildleve", this);
            propPacketUtil.AddProperty(String.Format("work.guildleveId[{0}]", slot));
            QueuePackets(propPacketUtil.Done());
        }

        private void SendLocalGuildleveClientUpdate(int localSlot)
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("playerWork/journal", this);
            propPacketUtil.AddProperty(String.Format("playerWork.questGuildleve[{0}]", localSlot));
            propPacketUtil.NewTarget("work/guildleve");
            propPacketUtil.AddProperty(String.Format("work.guildleveId[{0}]", LOCAL_GUILDLEVE_FIRST_SLOT + localSlot));
            QueuePackets(propPacketUtil.Done());
        }

        private void SendGuildleveMarkClientUpdate(int slot)
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("work/guildleve", this);
            propPacketUtil.AddProperty(String.Format("work.guildleveDone[{0}]", slot));
            propPacketUtil.AddProperty(String.Format("work.guildleveChecked[{0}]", slot));
            QueuePackets(propPacketUtil.Done());
        }

        public void SendStartCastbar(uint commandId, uint endTime)
        {
            playerWork.castCommandClient = commandId;
            playerWork.castEndClient = endTime;
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("playerWork/castState", this);
            propPacketUtil.AddProperty("playerWork.castEndClient");
            propPacketUtil.AddProperty("playerWork.castCommandClient");
            QueuePackets(propPacketUtil.Done());
        }

        public void SendEndCastbar()
        {
            playerWork.castCommandClient = 0;
            playerWork.castEndClient = 0;
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("playerWork/castState", this);
            propPacketUtil.AddProperty("playerWork.castCommandClient");
            QueuePackets(propPacketUtil.Done());
        }

        public void SetLoginDirector(Director director)
        {
            if (ownedDirectors.Contains(director))
                loginInitDirector = director;
        }

        public void AddDirector(Director director, bool spawnImmediatly = false)
        {
            if (!ownedDirectors.Contains(director))
            {
                ownedDirectors.Add(director);
                director.AddMember(this);
            }
        }

        public void OnZoneInComplete()
        {
            LuaEngine.GetInstance().CallLuaFunction(this, CurrentArea, "onZoneInComplete", true);
            foreach (Director director in new List<Director>(ownedDirectors))
                director.OnZoneInComplete(this);
            foreach (Quest quest in questScenario)
                quest?.OnZoneInComplete(this);
        }

        public void SendDirectorPackets(Director director)
        {
            QueuePackets(director.GetSpawnPackets());
            QueuePackets(director.GetInitPackets());
        }

        public void RemoveDirector(Director director)
        {
            if (ownedDirectors.Contains(director))
            {
                QueuePacket(RemoveActorPacket.BuildPacket(director.Id));
                ownedDirectors.Remove(director);
                if (loginInitDirector == director)
                    loginInitDirector = null;
                director.RemoveMember(this);
            }
        }

        public GuildleveDirector GetGuildleveDirector()
        {
            foreach (Director d in ownedDirectors)
            {
                if (d is GuildleveDirector)
                    return (GuildleveDirector)d;
            }

            return null;
        }

        public Director GetDirector(string directorName)
        {
            foreach (Director d in ownedDirectors)
            {
                if (d.GetScriptPath().Equals(directorName))
                    return d;
            }

            return null;
        }

        public Director GetDirector(uint id)
        {
            foreach (Director d in ownedDirectors)
            {
                if (d.Id == id)
                    return d;
            }

            return null;
        }

        public void ExaminePlayer(Actor examinee)
        {
            Player toBeExamined;
            if (examinee is Player)
                toBeExamined = (Player)examinee;
            else
                return;

            QueuePacket(InventoryBeginChangePacket.BuildPacket(toBeExamined.Id, true));
            toBeExamined.GetEquipment().SendUpdateAsItemPackage(this, ItemPackage.MAXSIZE_EQUIPMENT_OTHERPLAYER, ItemPackage.EQUIPMENT_OTHERPLAYER);
            QueuePacket(InventoryEndChangePacket.BuildPacket(toBeExamined.Id));
        }

        public void SendDataPacket(params object[] parameters)
        {
            List<LuaParam> lParams = LuaUtils.CreateLuaParamList(parameters);
            SubPacket spacket = GenericDataPacket.BuildPacket(Id, lParams);
            spacket.DebugPrintSubPacket();
            QueuePacket(spacket);
        }

        public void StartEvent(Actor owner, EventStartPacket start)
        {
            currentEventOwner = start.ownerActorID;
            currentEventName = start.eventName;
            currentEventType = start.eventType;
            LuaEngine.GetInstance().EventStarted(this, owner, start);
        }

        public void UpdateEvent(EventUpdatePacket update)
        {
            LuaEngine.GetInstance().OnEventUpdate(this, update.luaParams);
        }

        public void KickEvent(Actor actor, string eventName, params object[] parameters)
        {
            if (actor == null)
                return;

            List<LuaParam> lParams = LuaUtils.CreateLuaParamList(parameters);
            SubPacket spacket = KickEventPacket.BuildPacket(Id, actor.Id, eventName, 5, lParams);
            spacket.DebugPrintSubPacket();
            QueuePacket(spacket);
        }

        public void KickEventSpecial(Actor actor, uint unknown, string eventName, params object[] parameters)
        {
            if (actor == null)
                return;

            List<LuaParam> lParams = LuaUtils.CreateLuaParamList(parameters);
            SubPacket spacket = KickEventPacket.BuildPacket(Id, actor.Id, eventName, 5, lParams);
            spacket.DebugPrintSubPacket();
            QueuePacket(spacket);
        }

        public void SetEventStatus(Actor actor, string conditionName, bool enabled, byte type)
        {
            QueuePacket(SetEventStatusPacket.BuildPacket(actor.Id, enabled, type, conditionName));
        }

        public void RunEventFunction(string functionName, params object[] parameters)
        {
            List<LuaParam> lParams = LuaUtils.CreateLuaParamList(parameters);
            SubPacket spacket = RunEventFunctionPacket.BuildPacket(Id, currentEventOwner, currentEventName, currentEventType, functionName, lParams);
            spacket.DebugPrintSubPacket();
            QueuePacket(spacket);
        }

        public void EndEvent()
        {
            SubPacket p = EndEventPacket.BuildPacket(Id, currentEventOwner, currentEventName, currentEventType);
            p.DebugPrintSubPacket();
            QueuePacket(p);

            currentEventOwner = 0;
            currentEventName = "";
            currentEventType = 0;
            currentEventRunning = null;
        }

        public void BroadcastCountdown(byte countdownLength, ulong syncTime)
        {
            BroadcastPacket(StartCountdownPacket.BuildPacket(Id, countdownLength, syncTime, "Go!"), true);
        }

        public void SendInstanceUpdate(bool force = false)
        {
            //Update Instance
            List<Actor> aroundMe = new List<Actor>();

            if (CurrentArea != null)
                aroundMe.AddRange(CurrentArea.GetActorsAroundActor(this, 50));
            if (zone2 != null)
                aroundMe.AddRange(zone2.GetActorsAroundActor(this, 50));
            aroundMe.RemoveAll(a => a is Npc npc && npc.questGates != null && !CanSeeQuestNpc(npc));
            playerSession.UpdateInstance(aroundMe, force);
        }

        // A quest-owned actor exists for this player only while one of its quests is inside the gate's
        // sequence range and has set the class spawned. The range tells apart spawns of one class.
        public bool CanSeeQuestNpc(Npc npc)
        {
            if (npc.questGates == null)
                return true;
            uint classId = npc.GetActorClassId();
            foreach (QuestGate gate in npc.questGates)
            {
                Quest quest = questStateManager.GetActiveQuest(gate.questId);
                // A replaced quest stays active at SEQ_COMPLETED; its actors are gone.
                if (quest == null || quest.GetSequence() == Quest.SEQ_COMPLETED || !gate.Admits(quest.GetSequence()))
                    continue;
                QuestState.QuestENpc enpc = quest.GetQuestState()?.GetENpc(classId);
                if (enpc != null && enpc.isSpawned)
                    return true;
            }
            return false;
        }

        public void RefreshQuestNpcs()
        {
            if (playerSession == null || playerSession.isUpdatesLocked || isZoneChanging || CurrentArea == null)
                return;
            SendInstanceUpdate();
        }

        public bool IsInParty()
        {
            return currentParty != null;
        }

        public bool IsPartyLeader()
        {
            if (IsInParty())
            {
                Party party = (Party)currentParty;
                return party.GetLeader() == Id;
            }
            else
                return false;
        }

        public void PartyOustPlayer(uint actorId)
        {
            SubPacket oustPacket = PartyModifyPacket.BuildPacket(playerSession, 1, actorId);
            QueuePacket(oustPacket);
        }

        public void PartyOustPlayer(string name)
        {
            SubPacket oustPacket = PartyModifyPacket.BuildPacket(playerSession, 1, name);
            QueuePacket(oustPacket);
        }

        public void PartyLeave()
        {
            SubPacket leavePacket = PartyLeavePacket.BuildPacket(playerSession, false);
            QueuePacket(leavePacket);
        }

        public void PartyDisband()
        {
            SubPacket disbandPacket = PartyLeavePacket.BuildPacket(playerSession, true);
            QueuePacket(disbandPacket);
        }

        public void PartyPromote(uint actorId)
        {
            SubPacket promotePacket = PartyModifyPacket.BuildPacket(playerSession, 0, actorId);
            QueuePacket(promotePacket);
        }

        public void PartyPromote(string name)
        {
            SubPacket promotePacket = PartyModifyPacket.BuildPacket(playerSession, 0, name);
            QueuePacket(promotePacket);
        }

        //A party member list packet came, set the party
        public void SetParty(Party group)
        {
            if (group is Party && currentParty != group)
            {
                RemoveFromCurrentPartyAndCleanup();
                currentParty = group;
                SendOwnPartyOccupancy();
            }
        }

        public void SendOwnPartyOccupancy()
        {
            if (playerSession == null || !(currentParty is Party party))
                return;
            QueuePacket(SetOccupancyGroupPacket.BuildPacket(Id, party.groupIndex, Group.PlayerPartyGroup, 0));
        }

        //Removes the player from the party and cleans it up if needed
        public void RemoveFromCurrentPartyAndCleanup()
        {
            if (currentParty == null)
                return;

            Party partyGroup = (Party)currentParty;

            for (int i = 0; i < partyGroup.members.Count; i++)
            {
                if (partyGroup.members[i] == Id)
                {
                    partyGroup.members.RemoveAt(i);
                    break;
                }
            }

            //currentParty.members.Remove(this);
            if (partyGroup.members.Count == 0)
                Server.GetWorldManager().NoMembersInParty((Party)currentParty);

            currentParty = null;
        }

        public void IssueChocobo(byte appearanceId, string nameResponse)
        {
            Database.IssuePlayerChocobo(this, appearanceId, nameResponse);
            hasChocobo = true;
            chocoboAppearance = appearanceId;
            chocoboName = nameResponse;

            QueuePacket(SetChocoboNamePacket.BuildPacket(Id, chocoboName));
            QueuePacket(SetHasChocoboPacket.BuildPacket(Id, hasChocobo));
        }

        public void ChangeChocoboAppearance(byte appearanceId)
        {
            Database.ChangePlayerChocoboAppearance(this, appearanceId);
            chocoboAppearance = appearanceId;
        }

        public void StartChocoboRental(byte numMins)
        {
            rentalExpireTime = Utils.UnixTimeStampUTC() + ((uint)numMins * 60);
            rentalMinLeft = numMins;
        }

        public bool IsChocoboRentalActive()
        {
            return rentalExpireTime != 0;
        }

        public Retainer SpawnMyRetainer(Npc bell, int retainerIndex)
        {
            Retainer retainer = Database.LoadRetainer(this, retainerIndex);

            float distance = (float)Math.Sqrt(((positionX - bell.positionX) * (positionX - bell.positionX)) + ((positionZ - bell.positionZ) * (positionZ - bell.positionZ)));
            float posX = bell.positionX - ((-1.0f * (bell.positionX - positionX)) / distance);
            float posZ = bell.positionZ - ((-1.0f * (bell.positionZ - positionZ)) / distance);

            retainer.positionX = posX;
            retainer.positionY = positionY;
            retainer.positionZ = posZ;
            retainer.rotation = (float)Math.Atan2(positionX - posX, positionZ - posZ);

            retainerMeetingGroup = new RetainerMeetingRelationGroup(5555, this, retainer);
            retainerMeetingGroup.SendGroupPackets(playerSession);

            currentSpawnedRetainer = retainer;
            sentRetainerSpawn = false;

            return retainer;
        }

        public void DespawnMyRetainer()
        {
            if (currentSpawnedRetainer != null)
            {
                currentSpawnedRetainer = null;
                retainerMeetingGroup.SendDeletePacket(playerSession);
                retainerMeetingGroup = null;
            }
        }

        private DateTime lastUpdateTick;

        public override void Update(DateTime tick)
        {
            // A seamless crossing moves the player into a zone the same zone-loop pass may still update.
            if (tick == lastUpdateTick)
                return;
            lastUpdateTick = tick;

            UpdateInnResting(tick);
            UpdatePartyBonus(tick);
            UpdateKo(tick);

            // Chocobo Rental Expirey
            if (rentalExpireTime != 0)
            {
                uint tickUTC = Utils.UnixTimeStampUTC(tick);

                //Rental has expired, dismount
                if (rentalExpireTime <= tickUTC)
                {
                    rentalExpireTime = 0;
                    rentalMinLeft = 0;
                    ChangeMusic(CurrentArea.bgmDay);
                    SetMountState(0);
                    ChangeSpeed(0.0f, 2.0f, 5.0f, 5.0f);
                    ChangeState(0);
                }
                else
                {
                    rentalMinLeft = (byte)((rentalExpireTime - tickUTC) / 60);
                }
            }

            aiContainer.Update(tick);
            UpdateBattleMusic(tick);
            statusEffects.Update(tick);
            questStateManager.Update(tick);
        }

        public override void PostUpdate(DateTime tick, List<SubPacket> packets = null)
        {
            // todo: is this correct?
            if (this.playerSession.isUpdatesLocked)
                return;

            // todo: should probably add another flag for battleTemp since all this uses reflection
            packets = new List<SubPacket>();

            // we only want the latest update for the player
            if ((updateFlags & ActorUpdateFlags.Position) != 0)
            {
                if (positionUpdates.Count > 1)
                    positionUpdates.RemoveRange(1, positionUpdates.Count - 1);
            }

            if ((updateFlags & ActorUpdateFlags.HpTpMp) != 0)
            {
                // The client's target rank display listens to stateForAll.
                var propPacketUtil = new ActorPropertyPacketUtil("charaWork/stateForAll", this);
                propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkill[0]");
                propPacketUtil.AddProperty("charaWork.parameterSave.state_mainSkillLevel");

                packets.AddRange(propPacketUtil.Done());
            }


            if ((updateFlags & ActorUpdateFlags.Stats) != 0)
            {
                var propPacketUtil = new ActorPropertyPacketUtil("charaWork/battleParameter", this);

                for (uint i = 0; i < 35; i++)
                {
                    if (IsSyncedGeneralParameter((int)i) && GetMod(i) != charaWork.battleTemp.generalParameter[i])
                    {
                        charaWork.battleTemp.generalParameter[i] = (short)GetMod(i);
                        propPacketUtil.AddProperty(String.Format("charaWork.battleTemp.generalParameter[{0}]", i));
                    }
                }

                QueuePackets(propPacketUtil.Done());
                UpdateRemainBonusPoint();
            }

            if ((updateFlags & ActorUpdateFlags.Hotbar) != 0)
            {
                UpdateHotbar(hotbarSlotsToUpdate);
                hotbarSlotsToUpdate.Clear();

                updateFlags ^= ActorUpdateFlags.Hotbar;
            }

            // Checked here, on the zone thread where the position is applied, so the zone switch
            // can't race the zone loop.
            float seamFromX = positionX, seamFromZ = positionZ;
            base.PostUpdate(tick, packets);
            bool seamPending = seamlessCheckPending && !isZoneChanging;
            if (seamPending)
                seamlessCheckPending = false;
            if ((seamPending || positionX != seamFromX || positionZ != seamFromZ)
                && Server.GetWorldManager().SeamlessCheck(this, seamFromX, seamFromZ))
                SendInstanceUpdate();
        }

        public override void Die(DateTime tick, CommandResultContainer actionContainer = null)
        {
            // todo: death timer
            aiContainer.InternalDie(tick, 60);
        }

        //Update commands and recast timers for the entire hotbar
        public void UpdateHotbar()
        {
            for (ushort i = charaWork.commandBorder; i < charaWork.commandBorder + 30; i++)
            {
                hotbarSlotsToUpdate.Add(i);
            }
            updateFlags |= ActorUpdateFlags.Hotbar;
        }

        //Updates the hotbar and recast timers for only certain hotbar slots
        public void UpdateHotbar(List<ushort> slotsToUpdate)
        {
            UpdateHotbarCommands(slotsToUpdate);
            UpdateRecastTimers(slotsToUpdate);
        }

        //Update command ids for the passed in hotbar slots
        public void UpdateHotbarCommands(List<ushort> slotsToUpdate)
        {
            ActorPropertyPacketUtil propPacketUtil = new ActorPropertyPacketUtil("charaWork/command", this);
            foreach (ushort slot in slotsToUpdate)
            {
                propPacketUtil.AddProperty(String.Format("charaWork.command[{0}]", slot));
                propPacketUtil.AddProperty(String.Format("charaWork.commandCategory[{0}]", slot));
            }

            propPacketUtil.NewTarget("charaWork/commandDetailForSelf");
            //Enable or disable slots based on whether there is an ability in that slot
            foreach (ushort slot in slotsToUpdate)
            {
                charaWork.parameterSave.commandSlot_compatibility[slot - charaWork.commandBorder] = charaWork.command[slot] != 0;
                propPacketUtil.AddProperty(String.Format("charaWork.parameterSave.commandSlot_compatibility[{0}]", slot - charaWork.commandBorder));
            }

            QueuePackets(propPacketUtil.Done());
            //QueuePackets(compatibiltyUtil.Done());
        }

        //Update recast timers for the passed in hotbar slots
        public void UpdateRecastTimers(List<ushort> slotsToUpdate)
        {
            ActorPropertyPacketUtil recastPacketUtil = new ActorPropertyPacketUtil("charaWork/commandDetailForSelf", this);

            foreach (ushort slot in slotsToUpdate)
            {
                recastPacketUtil.AddProperty(String.Format("charaWork.parameterTemp.maxCommandRecastTime[{0}]", slot - charaWork.commandBorder));
                recastPacketUtil.AddProperty(String.Format("charaWork.parameterSave.commandSlot_recastTime[{0}]", slot - charaWork.commandBorder));
            }

            QueuePackets(recastPacketUtil.Done());
        }

        //Equips commandId in the first open slot of the current bar, unless it is already set.
        public void EquipAbilityInFirstOpenSlot(byte classId, uint commandId, bool printMessage = true)
        {
            if (classId != GetCurrentClassOrJob() || FindFirstCommandSlotById(commandId) < charaWork.commandBorder + 30)
                return;
            ushort hotbarSlot = FindFirstCommandSlotById(0);
            if (hotbarSlot >= charaWork.commandBorder + 30)
                return;
            EquipAbility(classId, commandId, hotbarSlot, printMessage);
        }

        //Sets commandId in hotbarSlot (commandBorder-based) of the loaded bar and saves it. A command
        //already on the bar is moved instead, and a current-class action it displaces goes back into
        //the first open slot, since those can't be unset.
        public void EquipAbility(byte classId, uint commandId, ushort hotbarSlot, bool printMessage = true)
        {
            int border = charaWork.commandBorder;
            commandId &= 0xFFFF;
            if (classId != GetCurrentClassOrJob() || hotbarSlot < border || hotbarSlot >= border + 30 || commandId == 0)
            {
                Program.Log.Warn("[hotbar] {0}: EquipAbility({1}, {2}, {3}) ignored", Name, classId, commandId, hotbarSlot);
                return;
            }

            ushort oldSlot = FindFirstCommandSlotById(commandId);
            if (oldSlot < border + 30)
            {
                if (oldSlot != hotbarSlot)
                    SwapAbilities(oldSlot, hotbarSlot);
                return;
            }

            bool displacedOwn = IsOwnAction(charaWork.command[hotbarSlot]);
            var ability = Server.GetWorldManager().GetBattleCommand(commandId);
            ushort lowHotbarSlot = (ushort)(hotbarSlot - border);
            ushort maxRecastTime = (ushort)(ability != null ? ability.maxRecastTimeSeconds : 5);
            uint recastEnd = Utils.UnixTimeStampUTC() + maxRecastTime;

            charaWork.command[hotbarSlot] = 0xA0F00000 | commandId;
            charaWork.commandCategory[hotbarSlot] = 1;
            charaWork.parameterTemp.maxCommandRecastTime[lowHotbarSlot] = maxRecastTime;
            charaWork.parameterSave.commandSlot_recastTime[lowHotbarSlot] = recastEnd;
            SaveHotbarSlot(hotbarSlot);

            if(printMessage)
                SendGameMessage(Server.GetWorldManager().GetActor(), 30603, 0x20, (int)(lowHotbarSlot + 1), commandId);

            if (displacedOwn)
                PlaceLearnedActions();
        }

        //Writes slot (commandBorder-based) of the loaded bar to the current class or job's saved bar
        //and queues it for the client.
        private void SaveHotbarSlot(ushort slot)
        {
            ushort low = (ushort)(slot - charaWork.commandBorder);
            Database.EquipAbility(this, GetCurrentClassOrJob(), low, charaWork.command[slot] & 0xFFFF, charaWork.parameterSave.commandSlot_recastTime[low]);
            hotbarSlotsToUpdate.Add(slot);
            updateFlags |= ActorUpdateFlags.Hotbar;
        }

        //An action of the current class, or of a job's base class: placed by the server, never unset.
        public bool IsOwnAction(uint command)
        {
            if ((command & 0xFFFF) == 0)
                return false;
            BattleCommand ability = Server.GetWorldManager().GetBattleCommand(command & 0xFFFF);
            if (ability == null || ability.job == 0)
                return false;
            byte current = GetCurrentClassOrJob();
            return ability.job == current || ability.job == ActionClassFor(current);
        }

        //Swaps two slots of the current bar; hotbarSlot1 and 2 are commandBorder-based.
        public void SwapAbilities(ushort hotbarSlot1, ushort hotbarSlot2)
        {
            int border = charaWork.commandBorder;
            if (hotbarSlot1 < border || hotbarSlot1 >= border + 30 || hotbarSlot2 < border || hotbarSlot2 >= border + 30 || hotbarSlot1 == hotbarSlot2)
                return;
            int low1 = hotbarSlot1 - border;
            int low2 = hotbarSlot2 - border;

            uint command = charaWork.command[hotbarSlot1];
            byte category = charaWork.commandCategory[hotbarSlot1];
            uint recastEnd = charaWork.parameterSave.commandSlot_recastTime[low1];
            ushort recastMax = charaWork.parameterTemp.maxCommandRecastTime[low1];

            charaWork.command[hotbarSlot1] = charaWork.command[hotbarSlot2];
            charaWork.commandCategory[hotbarSlot1] = charaWork.commandCategory[hotbarSlot2];
            charaWork.parameterSave.commandSlot_recastTime[low1] = charaWork.parameterSave.commandSlot_recastTime[low2];
            charaWork.parameterTemp.maxCommandRecastTime[low1] = charaWork.parameterTemp.maxCommandRecastTime[low2];

            charaWork.command[hotbarSlot2] = command;
            charaWork.commandCategory[hotbarSlot2] = category;
            charaWork.parameterSave.commandSlot_recastTime[low2] = recastEnd;
            charaWork.parameterTemp.maxCommandRecastTime[low2] = recastMax;

            SaveHotbarSlot(hotbarSlot1);
            SaveHotbarSlot(hotbarSlot2);
        }

        //hotbarSlot is 1-based (the Action Setting slot number, as EquipAbilityCommand gets it).
        //Current-class actions are not unset (the client has no way to set them again).
        public bool UnequipAbility(ushort hotbarSlot, bool printMessage = true)
        {
            if (hotbarSlot < 1 || hotbarSlot > 30)
                return false;
            ushort trueHotbarSlot = (ushort)(hotbarSlot + charaWork.commandBorder - 1);
            uint commandId = charaWork.command[trueHotbarSlot];
            if (commandId == 0 || IsOwnAction(commandId))
                return false;

            charaWork.command[trueHotbarSlot] = 0;
            charaWork.commandCategory[trueHotbarSlot] = 0;
            charaWork.parameterSave.commandSlot_recastTime[hotbarSlot - 1] = 0;
            charaWork.parameterTemp.maxCommandRecastTime[hotbarSlot - 1] = 0;
            SaveHotbarSlot(trueHotbarSlot);

            if (printMessage)
                SendGameMessage(Server.GetWorldManager().GetActor(), 30604, 0x20, (int)hotbarSlot, commandId & 0xFFFF);
            return true;
        }

        //Finds the first hotbar slot with a given commandId.
        //If the returned value is outside the hotbar, it indicates it wasn't found.
        public ushort FindFirstCommandSlotById(uint commandId)
        {
            if (commandId != 0)
                commandId |= 0xA0F00000;

            ushort firstSlot = (ushort)(charaWork.commandBorder + 30);

            for (ushort i = charaWork.commandBorder; i < charaWork.commandBorder + 30; i++)
            {
                if (charaWork.command[i] == commandId)
                {
                    firstSlot = i;
                    break;
                }
            }

            return firstSlot;
        }

        private void UpdateHotbarTimer(uint commandId, uint recastTimeMs)
        {
            ushort slot = FindFirstCommandSlotById(commandId);
            charaWork.parameterSave.commandSlot_recastTime[slot - charaWork.commandBorder] = Utils.UnixTimeStampUTC(DateTime.Now.AddMilliseconds(recastTimeMs));
            var slots = new List<ushort>();
            slots.Add(slot);
            UpdateRecastTimers(slots);
        }

        private uint GetHotbarTimer(uint commandId)
        {
            ushort slot = FindFirstCommandSlotById(commandId);
            return charaWork.parameterSave.commandSlot_recastTime[slot - charaWork.commandBorder];
        }

        public override void Cast(uint spellId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.Cast(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), spellId);
            else if (aiContainer.IsCurrentState<MagicState>())
                // You are already casting.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32536, 0x20);
            else
                // Please wait a moment and try again.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32535, 0x20);
        }

        public override void Ability(uint abilityId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.Ability(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), abilityId);
            else
                // Please wait a moment and try again.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32535, 0x20);
        }

        public override void WeaponSkill(uint skillId, uint targetId = 0)
        {
            if (aiContainer.CanChangeState())
                aiContainer.WeaponSkill(CurrentArea.FindActorInArea<Character>(targetId == 0 ? currentTarget : targetId), skillId);
            else
                // Please wait a moment and try again.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32535, 0x20);
        }

        public override bool IsValidTarget(Character target, ValidTarget validTarget)
        {
            if (target == null)
            {
                // Target does not exist.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32511, 0x20);
                return false;
            }

            if (target.isMovingToSpawn)
            {
                // That command cannot be performed on the current target.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32547, 0x20);
                return false;
            }

            // enemy only
            if ((validTarget & ValidTarget.Enemy) != 0)
            {
                // todo: this seems ambiguous
                if (target.isStatic)
                {
                    // That command cannot be performed on the current target.
                    SendGameMessage(Server.GetWorldManager().GetActor(), 32547, 0x20);
                    return false;
                }
                if (currentParty != null && target.currentParty == currentParty)
                {
                    // That command cannot be performed on a party member.
                    SendGameMessage(Server.GetWorldManager().GetActor(), 32548, 0x20);
                    return false;
                }
                // todo: pvp?
                if (Meteor.Map.AI.Factions.IsFriendly(target, this))
                {
                    // That command cannot be performed on an ally.
                    SendGameMessage(Server.GetWorldManager().GetActor(), 32549, 0x20);
                    return false;
                }

                // Leve targets can only be engaged by that leve's participants: 50031 "Invalid target."
                if (target is BattleNpc leveMob && leveMob.leveDirector != null && !leveMob.leveDirector.IsParticipant(this))
                {
                    SendGameMessage(Server.GetWorldManager().GetActor(), 50031, 0x20);
                    return false;
                }

                bool partyEngaged = false;
                // todo: replace with confrontation status effect? (see how dsp does it)
                if (target.aiContainer.IsEngaged())
                {
                    if (currentParty != null)
                    {
                        if (target is BattleNpc)
                        {
                            var helpingActorId = ((BattleNpc)target).GetMobMod((uint)MobModifier.CallForHelp);
                            partyEngaged = this.Id == helpingActorId || (((BattleNpc)target).GetMobMod((uint)MobModifier.FreeForAll) != 0);
                        }

                        if (!partyEngaged)
                        {
                            foreach (var memberId in ((Party)currentParty).members)
                            {
                                if (memberId == target.currentLockedTarget)
                                {
                                    partyEngaged = true;
                                    break;
                                }
                            }
                        }

                        if (!partyEngaged && target is BattleNpc && ((BattleNpc)target).IsEngagedWithSideOf(this))
                            partyEngaged = true;
                    }
                    else if (target.currentLockedTarget == Id || (target is BattleNpc && ((BattleNpc)target).IsEngagedWithSideOf(this)))
                    {
                        partyEngaged = true;
                    }
                }
                else
                {
                    partyEngaged = true;
                }

                if (!partyEngaged)
                {
                    // That target is already engaged.
                    SendGameMessage(Server.GetWorldManager().GetActor(), 32520, 0x20);
                    return false;
                }
            }

            if ((validTarget & ValidTarget.Ally) != 0 && !Meteor.Map.AI.Factions.IsFriendly(target, this))
            {
                // That command cannot be performed on the current target.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32547, 0x20);
                return false;
            }

            // todo: isStatic seems ambiguous?
            if ((validTarget & ValidTarget.NPC) != 0 && target.isStatic)
                return true;

            // todo: why is player always zoning?
            // cant target if zoning
            if (target is Player && ((Player)target).playerSession.isUpdatesLocked)
            {
                // That command cannot be performed on the current target.
                SendGameMessage(Server.GetWorldManager().GetActor(), 32547, 0x20);
                return false;
            }

            return true;
        }

        //Do we need separate functions? they check the same things
        public override uint GetAttackRange()
        {
            if (GetMod((uint)Modifier.AttackRange) > 3)
                return (uint)GetMod((uint)Modifier.AttackRange);
            switch (GetClass())
            {
                case CLASSID_LNC:
                case CLASSID_THM:
                    return 8;
                default:
                    return 5;
            }
        }

        public override bool CanUse(Character target, BattleCommand skill, CommandResult error = null)
        {
            if (IsRaiseLocked())
            {
                error?.SetTextId(32708);
                return false;
            }

            if (!skill.IsValidMainTarget(this, target, error) || !IsValidTarget(target, skill.mainTarget))
            {
                // error packet is set in IsValidTarget
                return false;
            }

            //Might want to do these with a BattleAction instead to be consistent with the rest of command stuff
            if (GetHotbarTimer(skill.id) > Utils.UnixTimeStampUTC())
            {
                // todo: this needs confirming
                // Please wait a moment and try again.
                error?.SetTextId(32535);
                return false;
            }

            ushort rangeError = CheckRange(target, skill.range, skill.minRange, skill.rangeHeight);
            if (rangeError != 0)
            {
                error?.SetTextId(rangeError);
                return false;
            }

            if (skill.commandType == CommandType.WeaponSkill && IsHostileTo(target) && !FacesTarget(target))
            {
                error?.SetTextId(32537);
                return false;
            }

            if (skill.CalculateMpCost(this) > GetMP())
            {
                // You do not have enough MP.
                error?.SetTextId(32545);
                return false;
            }

            if (skill.CalculateTpCost(this) > GetTP())
            {
                // You do not have enough TP.
                error?.SetTextId(32546);
                return false;
            }

            //Proc requirement
            if (skill.procRequirement != BattleCommandProcRequirement.None && !charaWork.battleTemp.timingCommandFlag[(int)skill.procRequirement - 1])
            {
                //Conditions for use are not met
                error?.SetTextId(32556);
                return false;
            }


            return true;
        }

        public override void OnAttack(State state, CommandResult action, ref CommandResult error)
        {
            var target = state.GetTarget();

            base.OnAttack(state, action, ref error);

            // todo: switch based on main weap (also probably move this anim assignment somewhere else)
            action.animation = 0x19001000;
            if (error == null)
            {
                // melee attack animation
                //action.animation = 0x19001000;
            }
            if (target is BattleNpc)
            {
                ((BattleNpc)target).hateContainer.UpdateHate(this, action.enmity);
            }

            LuaEngine.GetInstance().OnSignal("playerAttack");
        }

        public override void OnCast(State state, CommandResult[] actions, BattleCommand spell, ref CommandResult[] errors)
        {
            // todo: update hotbar timers to skill's recast time (also needs to be done on class change or equip crap)
            base.OnCast(state, actions, spell, ref errors);
            // todo: should just make a thing that updates the one slot cause this is dumb as hell            
            UpdateHotbarTimer(spell.id, spell.recastTimeMs);
            //LuaEngine.GetInstance().OnSignal("spellUse");
        }

        public override void OnWeaponSkill(State state, CommandResult[] actions, BattleCommand skill, ref CommandResult[] errors)
        {
            // todo: update hotbar timers to skill's recast time (also needs to be done on class change or equip crap)
            base.OnWeaponSkill(state, actions, skill, ref errors);

            // todo: should just make a thing that updates the one slot cause this is dumb as hell
            UpdateHotbarTimer(skill.id, skill.recastTimeMs);
            // todo: this really shouldnt be called on each ws?
            lua.LuaEngine.CallLuaPlayerFunction(this, "onWeaponSkill", this, state.GetTarget(), skill);
            LuaEngine.GetInstance().OnSignal("weaponskillUse");
        }

        public override void OnAbility(State state, CommandResult[] actions, BattleCommand ability, ref CommandResult[] errors)
        {
            base.OnAbility(state, actions, ability, ref errors);
            UpdateHotbarTimer(ability.id, ability.recastTimeMs);
            LuaEngine.GetInstance().OnSignal("abilityUse");
        }

        //Handles exp being added, does not handle figuring out exp bonus from buffs or skill/link chains or any of that
        //Returns CommandResults that can be sent to display the EXP gained number and level ups
        //exp should be a ushort single the exp graphic overflows after ~65k
        public List<CommandResult> AddExp(int exp, byte classId, byte bonusPercent = 0)
        {
            List<CommandResult> actionList = new List<CommandResult>();
            exp += (int)Math.Ceiling((exp * bonusPercent / 100.0f));

            //You earn [exp] (+[bonusPercent]%) experience points.
            //In non-english languages there are unique messages for each language, hence the use of ClassExperienceTextIds
            actionList.Add(new CommandResult(Id, BattleUtils.ClassExperienceTextIds[classId], 0, (ushort)exp, bonusPercent));

            bool leveled = false;
            // classId may not be the current class.
            Func<short> classLevel = () => (short)Math.Max((short)1, charaWork.battleSave.skillLevel[classId - 1]);
            int diff = MAXEXP[classLevel() - 1] - charaWork.battleSave.skillPoint[classId - 1];
            //While there is enough experience to level up, keep leveling up, unlocking skills and removing experience from exp until we don't have enough to level up
            while (exp >= diff && classLevel() < charaWork.battleSave.skillLevelCap[classId])
            {
                LevelUp(classId, actionList);
                leveled = true;
                exp -= diff;
                diff = MAXEXP[classLevel() - 1];
            }

            if (leveled)
            {
                //Set exp to current class to 0 so that exp is added correctly
                charaWork.battleSave.skillPoint[classId - 1] = 0;
                //send new level
                ActorPropertyPacketUtil levelPropertyPacket = new ActorPropertyPacketUtil("charaWork/stateForAll", this);
                levelPropertyPacket.AddProperty(string.Format("charaWork.battleSave.skillLevel[{0}]", classId - 1));
                levelPropertyPacket.AddProperty("charaWork.parameterSave.state_mainSkillLevel");
                QueuePackets(levelPropertyPacket.Done());

                Database.SetLevel(this, classId, classLevel());
                Database.SavePlayerCurrentClass(this);
            }
            //Cap experience for level 50
            charaWork.battleSave.skillPoint[classId - 1] = Math.Min(charaWork.battleSave.skillPoint[classId - 1] + exp, MAXEXP[classLevel() - 1]);

            ActorPropertyPacketUtil expPropertyPacket = new ActorPropertyPacketUtil("charaWork/battleStateForSelf", this);
            expPropertyPacket.AddProperty(string.Format("charaWork.battleSave.skillPoint[{0}]", classId - 1));

            QueuePackets(expPropertyPacket.Done());
            Database.SetExp(this, classId, charaWork.battleSave.skillPoint[classId - 1]);

            return actionList;
        }

        //Job id -> the base class whose level gates its actions.
        private static byte ActionClassFor(byte job)
        {
            switch (job)
            {
                case 15: return CLASSID_PUG;
                case 16: return CLASSID_GLA;
                case 17: return CLASSID_MRD;
                case 18: return CLASSID_ARC;
                case 19: return CLASSID_LNC;
                case 26: return CLASSID_THM;
                case 27: return CLASSID_CNJ;
                default: return job;
            }
        }

        //Puts every learned action of the current class (and, on a job, its base class) on the bar.
        //The Action Setting menu can't set the current class's own actions, so the server must place
        //them, including for a class levelled by GM or a missed level-up.
        public void PlaceLearnedActions()
        {
            byte current = GetCurrentClassOrJob();
            byte baseClass = ActionClassFor(current);
            int border = charaWork.commandBorder;
            var learned = new List<BattleCommand>();
            foreach (BattleCommand command in Server.GetWorldManager().GetAllBattleCommands())
            {
                if (command.job == 0 || (command.job != current && command.job != baseClass))
                    continue;
                byte classId = ActionClassFor(command.job);
                if (classId < 1 || classId > charaWork.battleSave.skillLevel.Length || charaWork.battleSave.skillLevel[classId - 1] < command.level)
                    continue;
                learned.Add(command);
            }
            learned.Sort((a, b) => a.level != b.level ? a.level.CompareTo(b.level) : a.id.CompareTo(b.id));
            foreach (BattleCommand command in learned)
            {
                if (FindFirstCommandSlotById(command.id) < border + 30)
                    continue;
                ushort slot = FindFirstCommandSlotById(0);
                if (slot >= border + 30)
                    break;
                EquipAbility(current, command.id, slot, false);
            }
        }

        //commandAcquired marks a class action as learned, at element id - 26001; ActionEquipWidget lists
        //those. Job actions use the base class level.
        public void RefreshAcquiredCommands(bool send)
        {
            ActorPropertyPacketUtil propPacketUtil = send ? new ActorPropertyPacketUtil("charaWork/command", this) : null;
            bool changed = false;
            foreach (BattleCommand command in Server.GetWorldManager().GetAllBattleCommands())
            {
                int index = command.id - 26001;
                if (command.job == 0 || index < 0 || index >= charaWork.commandAcquired.Length)
                    continue;
                byte classId = ActionClassFor(command.job);
                if (classId < 1 || classId > charaWork.battleSave.skillLevel.Length)
                    continue;
                bool learned = charaWork.battleSave.skillLevel[classId - 1] >= command.level;
                if (learned != charaWork.commandAcquired[index])
                {
                    charaWork.commandAcquired[index] = learned;
                    propPacketUtil?.AddProperty(String.Format("charaWork.commandAcquired[{0}]", index));
                    changed = true;
                }
            }
            if (send && changed)
                QueuePackets(propPacketUtil.Done());
        }

        //After a level is lowered, takes the current class's actions above it off the loaded bar.
        //UnequipAbility can't, since these are server-placed.
        private void RemoveUnlearnedActions()
        {
            byte current = GetCurrentClassOrJob();
            byte baseClass = ActionClassFor(current);
            for (ushort slot = charaWork.commandBorder; slot < charaWork.commandBorder + 30; slot++)
            {
                BattleCommand command = Server.GetWorldManager().GetBattleCommand(charaWork.command[slot] & 0xFFFF);
                if (command == null || command.job == 0 || (command.job != current && command.job != baseClass))
                    continue;
                byte classId = ActionClassFor(command.job);
                if (classId < 1 || classId > charaWork.battleSave.skillLevel.Length || charaWork.battleSave.skillLevel[classId - 1] >= command.level)
                    continue;
                ushort low = (ushort)(slot - charaWork.commandBorder);
                charaWork.command[slot] = 0;
                charaWork.commandCategory[slot] = 0;
                charaWork.parameterSave.commandSlot_recastTime[low] = 0;
                charaWork.parameterTemp.maxCommandRecastTime[low] = 0;
                SaveHotbarSlot(slot);
            }
        }

        //Marks the level's actions learned and places them on the loaded bar; other bars get them when
        //loaded. If actionList is not null, adds a "You learn Command" message.
        private void EquipAbilitiesAtLevel(byte classId, short level, List<CommandResult> actionList = null)
        {
            RefreshAcquiredCommands(true);
            byte current = GetCurrentClassOrJob();
            if (classId == current || classId == ActionClassFor(current))
                PlaceLearnedActions();

            List<ushort> commandIds = Server.GetWorldManager().GetBattleCommandIdByLevel(classId, level);
            foreach (ushort commandId in commandIds)
            {
                byte jobId = ConvertClassIdToJobId(classId);

                //33926: You learn [command].
                if (actionList != null)
                {
                    if (classId == GetCurrentClassOrJob() || jobId == GetCurrentClassOrJob())
                        actionList.Add(new CommandResult(Id, 33926, 0, commandId));
                }
            }
        }

        //Increaess level of current class and equips new abilities earned at that level
        public void LevelUp(byte classId, List<CommandResult> actionList = null)
        {
            if (charaWork.battleSave.skillLevel[classId - 1] < charaWork.battleSave.skillLevelCap[classId])
            {
                //Increase level
                charaWork.battleSave.skillLevel[classId - 1]++;
                if (classId == GetClass())
                    charaWork.parameterSave.state_mainSkillLevel = charaWork.battleSave.skillLevel[classId - 1];

                //33909: You attain level [level].
                if (actionList != null)
                    actionList.Add(new CommandResult(Id, 33909, 0, (ushort)charaWork.battleSave.skillLevel[classId - 1], classId));

                EquipAbilitiesAtLevel(classId, charaWork.battleSave.skillLevel[classId - 1], actionList);
                questStateManager.UpdateLevel(GetHighestLevel());
                if (classId == GetClass())
                {
                    CalculateBaseStats();
                    if (IsAlive())
                    {
                        SetHP((uint)GetMaxHP());
                        SetMP((uint)GetMaxMP());
                    }
                }
            }
        }

        // Lowering a level takes the actions above it off the loaded bar.
        public List<CommandResult> SetClassLevel(byte classId, short level)
        {
            List<CommandResult> actionList = new List<CommandResult>();
            if (classId < 1 || classId > charaWork.battleSave.skillLevel.Length)
                return actionList;
            short cap = charaWork.battleSave.skillLevelCap[classId];
            level = Math.Max((short)1, Math.Min(level, cap));
            bool current = classId == GetClass();

            if (level > charaWork.battleSave.skillLevel[classId - 1])
            {
                while (charaWork.battleSave.skillLevel[classId - 1] < level)
                {
                    short before = charaWork.battleSave.skillLevel[classId - 1];
                    LevelUp(classId, actionList);
                    if (charaWork.battleSave.skillLevel[classId - 1] == before)
                        break;
                }
            }
            else if (level < charaWork.battleSave.skillLevel[classId - 1])
            {
                charaWork.battleSave.skillLevel[classId - 1] = level;
                questStateManager.UpdateLevel(GetHighestLevel());
                RefreshAcquiredCommands(true);
                if (classId == GetCurrentClassOrJob() || classId == ActionClassFor(GetCurrentClassOrJob()))
                    RemoveUnlearnedActions();
                if (current)
                {
                    charaWork.parameterSave.state_mainSkillLevel = level;
                    CalculateBaseStats();
                    if (IsAlive())
                    {
                        SetHP((uint)Math.Min(GetHP(), GetMaxHP()));
                        SetMP((uint)Math.Min(GetMP(), GetMaxMP()));
                    }
                }
            }

            charaWork.battleSave.skillPoint[classId - 1] = 0;

            ActorPropertyPacketUtil levelPropertyPacket = new ActorPropertyPacketUtil("charaWork/stateForAll", this);
            levelPropertyPacket.AddProperty(string.Format("charaWork.battleSave.skillLevel[{0}]", classId - 1));
            levelPropertyPacket.AddProperty("charaWork.parameterSave.state_mainSkillLevel");
            QueuePackets(levelPropertyPacket.Done());
            ActorPropertyPacketUtil expPropertyPacket = new ActorPropertyPacketUtil("charaWork/battleStateForSelf", this);
            expPropertyPacket.AddProperty(string.Format("charaWork.battleSave.skillPoint[{0}]", classId - 1));
            QueuePackets(expPropertyPacket.Done());

            Database.SetLevel(this, classId, level);
            Database.SetExp(this, classId, 0);
            if (current)
                Database.SavePlayerCurrentClass(this);
            return actionList;
        }

        public static byte ConvertClassIdToJobId(byte classId)
        {
            byte jobId = classId;

            switch (classId)
            {
                case CLASSID_PUG:
                case CLASSID_GLA:
                case CLASSID_MRD:
                    jobId += 13;
                    break;
                case CLASSID_ARC:
                case CLASSID_LNC:
                    jobId += 11;
                    break;
                case CLASSID_THM:
                case CLASSID_CNJ:
                    jobId += 4;
                    break;
            }

            return jobId;
        }

        public void SetCurrentJob(byte jobId)
        {
            currentJob = jobId;
            BroadcastPacket(SetCurrentJobPacket.BuildPacket(Id, jobId), true);
            Database.LoadHotbar(this);
            SendCharaExpInfo();
        }

        //Gets the id of the player's current job. If they aren't a job, gets the id of their class
        public byte GetCurrentClassOrJob()
        {
            if (currentJob != 0)
                return (byte)currentJob;
            return charaWork.parameterSave.state_mainSkill[0];
        }

        public void hpstuff(uint hp)
        {
            SetMaxHP(hp);
            SetHP(hp);
            mpMaxBase = (ushort)hp;
            charaWork.parameterSave.mpMax = (short)hp;
            charaWork.parameterSave.mp = (short)hp;
            AddTP(3000);
            updateFlags |= ActorUpdateFlags.HpTpMp;
        }

        public void SetCombos(int comboId1 = 0, int comboId2 = 0)
        {
            SetCombos(new int[] { comboId1, comboId2 });
        }

        public void SetCombos(int[] comboIds)
        {
            Array.Copy(comboIds, playerWork.comboNextCommandId, 2);

            //If we're starting or continuing a combo chain, add the status effect and combo cost bonus
            if (comboIds[0] != 0)
            {
                // Refreshed, not overwritten: an overwrite runs Combo's onLose, which clears the chain just set.
                StatusEffect current = statusEffects.GetStatusEffectById((uint)StatusEffectId.Combo);
                if (current != null)
                    current.RefreshTime();
                else
                {
                    StatusEffect comboEffect = new StatusEffect(this, Server.GetWorldManager().GetStatusEffect((uint)StatusEffectId.Combo));
                    comboEffect.SetDuration(13);
                    comboEffect.SetOverwritable(1);
                    statusEffects.AddStatusEffect(comboEffect, this);
                }
                playerWork.comboCostBonusRate = 1;
            }
            //Otherwise we're ending a combo, remove the status
            else
            {
                statusEffects.RemoveStatusEffect(statusEffects.GetStatusEffectById((uint)StatusEffectId.Combo));
                playerWork.comboCostBonusRate = 0;
            }

            ActorPropertyPacketUtil comboPropertyPacket = new ActorPropertyPacketUtil("playerWork/combo", this);
            comboPropertyPacket.AddProperty("playerWork.comboCostBonusRate");
            comboPropertyPacket.AddProperty("playerWork.comboNextCommandId[0]");
            comboPropertyPacket.AddProperty("playerWork.comboNextCommandId[1]");
            QueuePackets(comboPropertyPacket.Done());
        }

        private int weaponBaseDelay = 0;
        private int weaponBaseHits = 0;

        public int GetWeaponBaseHits() { return weaponBaseHits; }

        // Statuses like Haste also change Delay and HitCount. Overwriting them here would let a status
        // undo itself twice when it wears off, so while any status is up only the weapon's change is
        // applied.
        private void RebaseWeaponMods(int delay, int hits)
        {
            bool hasEffects = false;
            if (statusEffects != null)
                foreach (var effect in statusEffects.GetStatusEffects())
                {
                    hasEffects = true;
                    break;
                }

            if (!hasEffects || weaponBaseDelay <= 0)
                SetMod((uint)Modifier.Delay, delay);
            else if (delay != weaponBaseDelay)
                SetMod((uint)Modifier.Delay, (long)Math.Round(GetMod(Modifier.Delay) * delay / (double)weaponBaseDelay));

            if (!hasEffects || weaponBaseHits <= 0)
                SetMod((uint)Modifier.HitCount, hits);
            else if (hits != weaponBaseHits)
                SetMod((uint)Modifier.HitCount, Math.Max(1, (long)GetMod(Modifier.HitCount) + hits - weaponBaseHits));

            weaponBaseDelay = delay;
            weaponBaseHits = hits;
        }

        // The client's CharaBaseClass calcPotencial. The client only checks it is positive (not an NM).
        private static readonly int[] POTENCIAL_LEVELS = { 98, 93, 88, 83, 78, 73, 68, 63, 58, 53, 48, 43, 38, 33, 28, 23, 18, 13, 9, 5, 1 };
        private static readonly float[] POTENCIAL_VALUES = { 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 };

        public static float CalcPotencial(int level)
        {
            for (int i = 0; i < POTENCIAL_LEVELS.Length; i++)
            {
                if (POTENCIAL_LEVELS[i] > level)
                    continue;
                if (i == 0 || level == POTENCIAL_LEVELS[i])
                    return POTENCIAL_VALUES[i];
                float t = (level - POTENCIAL_LEVELS[i]) / (float)(POTENCIAL_LEVELS[i - 1] - POTENCIAL_LEVELS[i]);
                return POTENCIAL_VALUES[i] + (POTENCIAL_VALUES[i - 1] - POTENCIAL_VALUES[i]) * t;
            }
            return 1.0f;
        }

        // 0% condition gives no stats. Items without durability on their sheet never break.
        public static bool IsGearBroken(InventoryItem item)
        {
            if (item == null || item.modifiers == null || item.modifiers.durability != 0)
                return false;
            ItemData data = Server.GetItemGamedata(item.itemId);
            return data != null && data.durability > 0;
        }

        public bool IsEquippedGearBroken(ushort slot)
        {
            return IsGearBroken(GetEquipment()?.GetItemAtSlot(slot));
        }

        public override void CalculateBaseStats()
        {
            charaWork.battleSave.potencial = CalcPotencial(GetLevel());

            var equip = GetEquipment();
            var mainHandItem = equip?.GetItemAtSlot(SLOT_MAINHAND);
            var damageAttribute = 0;
            var attackDelay = 3000;
            var hitCount = 1;

            if (mainHandItem != null)
            {
                var mainHandWeapon = (Server.GetItemGamedata(mainHandItem.itemId) as WeaponItem);
                if (mainHandWeapon != null)
                {
                    damageAttribute = mainHandWeapon.damageAttributeType1;
                    attackDelay = (int)(mainHandWeapon.damageInterval * 1000);
                    hitCount = Math.Max(1, (int)mainHandWeapon.frequency);
                }
            }

            var offHandItem = equip?.GetItemAtSlot(SLOT_OFFHAND);
            SetMod((uint)Modifier.CanBlock, offHandItem != null && !IsGearBroken(offHandItem) ? 1 : 0);

            SetMod((uint)Modifier.AttackType, damageAttribute);
            RebaseWeaponMods(attackDelay > 0 ? attackDelay : 3000, hitCount);

            // player.lua's onCalculateBaseStats sets the level, class and gear stats.
            if (!LuaEngine.CallLuaPlayerFunction(this, "onCalculateBaseStats", this))
            {
                SetBaseStat((uint)Modifier.Attack, (long)(GetMod(Modifier.Strength) * 0.667));
                SetBaseStat((uint)Modifier.Accuracy, (long)(GetMod(Modifier.Dexterity) * 0.667));
                SetBaseStat((uint)Modifier.Defense, (long)(GetMod(Modifier.Vitality) * 0.667));
                SetBaseStat((uint)Modifier.AttackMagicPotency, (long)(GetMod(Modifier.Intelligence) * 0.25));
                SetBaseStat((uint)Modifier.MagicAccuracy, (long)(GetMod(Modifier.Mind) * 0.25));
                SetBaseStat((uint)Modifier.HealingMagicPotency, (long)(GetMod(Modifier.Mind) * 0.25));
                SetBaseStat((uint)Modifier.MagicEvasion, (long)(GetMod(Modifier.Piety) * 0.25));
                SetBaseStat((uint)Modifier.EnfeeblingMagicPotency, (long)(GetMod(Modifier.Piety) * 0.25));
            }

            CalculateTraitMods();

            uint hpMax = (uint)GetMod(Modifier.Hp);
            if (hpMax > 0)
                charaWork.parameterSave.hpMax[0] = (short)Math.Min(hpMax, (uint)short.MaxValue);
            uint mpMax = (uint)GetMod(Modifier.Mp);
            if (mpMax > 0)
                charaWork.parameterSave.mpMax = (short)Math.Min(mpMax, (uint)short.MaxValue);

            if (charaWork.parameterSave.hp[0] > charaWork.parameterSave.hpMax[0])
                charaWork.parameterSave.hp[0] = charaWork.parameterSave.hpMax[0];
            if (charaWork.parameterSave.mp > charaWork.parameterSave.mpMax)
                charaWork.parameterSave.mp = charaWork.parameterSave.mpMax;

            updateFlags |= ActorUpdateFlags.HpTpMp | ActorUpdateFlags.Stats;
        }

        public bool HasTrait(ushort id)
        {
            BattleTrait trait = Server.GetWorldManager().GetBattleTrait(id);

            return HasTrait(trait);
        }

        public bool HasTrait(BattleTrait trait)
        {
            return (trait != null) && (trait.job == GetClass()) && (trait.level <= GetLevel());
        }

        #region Attribute (bonus) points
        // Jobs use their base class's points. Keep the rules in step with battle/stats.lua.
        private Dictionary<byte, int[]> bonusAllotments = new Dictionary<byte, int[]>();

        // MNK PGL, PLD GLA, WAR MRD, BRD ARC, DRG LNC, BLM THM, WHM CNJ.
        private static readonly Dictionary<byte, byte> JOB_BASE_CLASS = new Dictionary<byte, byte>
        {
            { 15, 2 }, { 16, 3 }, { 17, 4 }, { 18, 7 }, { 19, 8 }, { 26, 22 }, { 27, 23 },
        };

        public static int BonusPointTotal(int level)
        {
            return level < 10 ? 0 : 5 + (level - 10);
        }

        public static int BonusPointCap(int level)
        {
            return level < 10 ? 0 : 3 + (level - 9) / 2;
        }

        public bool HasBonusAllotment(byte classId)
        {
            return bonusAllotments.ContainsKey(classId);
        }

        // attribute: 0 STR, 1 VIT, 2 DEX, 3 INT, 4 MND, 5 PIE.
        public int GetBonusPoint(byte classId, int attribute)
        {
            int[] points;
            if (attribute < 0 || attribute > 5 || !bonusAllotments.TryGetValue(classId, out points))
                return 0;
            return points[attribute];
        }

        // The client's widget only adds points, so a lowered attribute is a forged request. Points come
        // back only through the Keeper's Hymn.
        public bool SetBonusAllotment(byte classId, int level, int str, int vit, int dex, int intel, int mnd, int pie)
        {
            int[] points = { str, vit, dex, intel, mnd, pie };
            int[] old;
            bonusAllotments.TryGetValue(classId, out old);
            int cap = BonusPointCap(level), sum = 0;
            for (int i = 0; i < points.Length; i++)
            {
                int p = points[i];
                if (p < 0 || p > cap || (old != null && p < old[i]))
                    return false;
                sum += p;
            }
            if (sum > BonusPointTotal(level))
                return false;
            bonusAllotments[classId] = points;
            Database.SaveBonusAllotment(this, classId, points);
            CalculateBaseStats();
            UpdateRemainBonusPoint();
            return true;
        }

        public void UpdateRemainBonusPoint(bool send = true)
        {
            byte classId = (byte)GetClass();
            byte baseClass;
            if (JOB_BASE_CLASS.TryGetValue(classId, out baseClass))
                classId = baseClass;
            int total = BonusPointTotal(GetLevel());
            int spent = 0;
            int[] points;
            if (bonusAllotments.TryGetValue(classId, out points))
                foreach (int p in points)
                    spent += p;
            bool remain = total - spent > 0;
            if (remain == playerWork.isRemainBonusPoint)
                return;
            playerWork.isRemainBonusPoint = remain;
            if (send && playerSession != null)
            {
                var util = new ActorPropertyPacketUtil("playerWork/consoleTray", this);
                util.AddProperty("playerWork.isRemainBonusPoint");
                QueuePackets(util.Done());
            }
        }
        #endregion

        #region Rested bonus
        public int restBonusPool;

        // Guesses: 1.x only said the pool fills "up to a maximum".
        public const double REST_POOL_CAP_LEVELS = 1.5;
        public const double REST_POOL_FILL_HOURS = 24.0;
        private const double REST_ACCRUE_CHECK_SECONDS = 1.0;

        public uint restInnLogoutTime;
        private DateTime nextInnRestCheck = DateTime.MinValue;
        private DateTime lastRestAccrue = DateTime.MinValue;
        private double restAccrueRemainder = 0;

        public bool HasRestedBonus()
        {
            return restBonusPool > 0;
        }

        public float GetRestBonusExpRate()
        {
            return restBonusPool > 0 ? 1.5f : 0.0f;
        }

        public void ConsumeRestedBonus(int expEarned)
        {
            if (restBonusPool <= 0 || expEarned <= 0 || GetLevel() >= 50)
                return;
            SetRestedBonusPool(Math.Max(0, restBonusPool - expEarned));
        }

        public int GetRestedBonusCap()
        {
            int level = Math.Max(1, Math.Min((int)GetLevel(), MAXEXP.Length));
            return (int)(MAXEXP[level - 1] * REST_POOL_CAP_LEVELS);
        }

        public void AccrueRestedHours(double hours)
        {
            if (hours <= 0)
                return;
            int cap = GetRestedBonusCap();
            if (restBonusPool >= cap)
                return;
            double gain = cap / REST_POOL_FILL_HOURS * hours + restAccrueRemainder;
            int whole = (int)Math.Floor(gain);
            restAccrueRemainder = gain - whole;
            if (whole > 0)
                SetRestedBonusPool(Math.Min(cap, restBonusPool + whole));
        }

        public void AccrueRestedOffline()
        {
            if (restInnLogoutTime == 0)
                return;
            uint now = Utils.UnixTimeStampUTC();
            if (now > restInnLogoutTime)
                AccrueRestedHours((now - restInnLogoutTime) / 3600.0);
            restInnLogoutTime = 0;
            Database.SetRestInnLogoutTime(this, 0);
        }

        private void UpdateInnResting(DateTime tick)
        {
            if (tick < nextInnRestCheck)
                return;
            nextInnRestCheck = tick.AddSeconds(REST_ACCRUE_CHECK_SECONDS);
            if (CurrentArea == null || IsZoneing || playerSession == null || playerSession.isUpdatesLocked || statusEffects == null)
                return;

            bool inInn = CurrentArea.isInn && IsAlive();
            StatusEffect resting = statusEffects.GetStatusEffectById((uint)StatusEffectId.Resting);
            CommandResultContainer results = new CommandResultContainer();
            bool changed = false;
            if (inInn && resting == null)
            {
                StatusEffect effect = Server.GetWorldManager().GetStatusEffect((uint)StatusEffectId.Resting);
                if (effect != null)
                {
                    effect.SetDuration(UInt32.MaxValue);
                    changed = statusEffects.AddStatusEffect(effect, this, results, effect.GetStatusGainTextId());
                }
                lastRestAccrue = tick;
            }
            else if (!inInn && resting != null)
                changed = statusEffects.RemoveStatusEffect(resting, results, resting.GetStatusLossTextId(), false);
            else if (resting != null)
            {
                if (lastRestAccrue != DateTime.MinValue)
                    AccrueRestedHours((tick - lastRestAccrue).TotalHours);
                lastRestAccrue = tick;
            }

            if (changed)
            {
                results.CombineLists();
                DoBattleAction(0, 0x7c000062, results.GetList());
            }
        }

        public void SetRestedBonusPool(int pool)
        {
            pool = Math.Max(0, pool);
            bool rateChanged = (pool > 0) != (restBonusPool > 0);
            restBonusPool = pool;
            Database.SetRestBonus(this, pool);
            if (rateChanged)
            {
                playerWork.restBonusExpRate = GetRestBonusExpRate();
                var propertyBuilder = new ActorPropertyPacketUtil("playerWork/expBonus", this);
                propertyBuilder.AddProperty("playerWork.restBonusExpRate");
                QueuePackets(propertyBuilder.Done());
            }
        }
        #endregion

        public void CalculateTraitMods()
        {
            var traitIds = Server.GetWorldManager().GetAllBattleTraitIdsForClass((byte)GetClass());

            var traitMods = new Dictionary<uint, double>();
            foreach (var traitId in traitIds)
            {
                var trait = Server.GetWorldManager().GetBattleTrait(traitId);
                if (HasTrait(trait))
                {
                    double current;
                    traitMods.TryGetValue(trait.modifier, out current);
                    traitMods[trait.modifier] = current + trait.bonus;
                }
            }
            ReplaceStatLayer("trait", traitMods);
        }

        public bool HasItemEquippedInSlot(uint itemId, ushort slot)
        {
            var equippedItem = equipment.GetItemAtSlot(slot);

            return equippedItem != null && equippedItem.itemId == itemId;
        }

        public Retainer GetSpawnedRetainer()
        {
            return currentSpawnedRetainer;
        }

        public void StartTradeTransaction(Player otherPlayer)
        {
            myOfferings = new ReferencedItemPackage(this, ItemPackage.MAXSIZE_TRADE, ItemPackage.TRADE);
            otherTrader = otherPlayer;
            isTradeAccepted = false;
        }

        public Player GetOtherTrader()
        {
            return otherTrader;
        }

        public ReferencedItemPackage GetTradeOfferings()
        {
            return myOfferings;
        }

        public bool IsTrading()
        {
            return otherTrader != null;
        }

        public bool IsTradeAccepted()
        {
            return isTradeAccepted;
        }

        public void AddTradeItem(ushort slot, ItemRefParam chosenItem, int tradeQuantity)
        {
            if (!IsTrading())
                return;

            //Get chosen item
            InventoryItem offeredItem = itemPackages[chosenItem.itemPackage].GetItemAtSlot(chosenItem.slot);
            offeredItem.SetTradeQuantity(tradeQuantity);

            myOfferings.Set(slot, offeredItem);
            SendTradePackets();
        }

        public void RemoveTradeItem(ushort slot)
        {
            if (!IsTrading())
                return;

            InventoryItem offeredItem = myOfferings.GetItemAtSlot(slot);
            offeredItem.SetNormal();

            myOfferings.Clear(slot);
            SendTradePackets();
        }

        public void ClearTradeItems()
        {
            if (!IsTrading())
                return;

            for (ushort i = 0; i < myOfferings.GetCapacity(); i++)
            {
                InventoryItem offeredItem = myOfferings.GetItemAtSlot(i);
                if (offeredItem != null)
                    offeredItem.SetNormal();
            }

            myOfferings.ClearAll();
            SendTradePackets();
        }

        private void SendTradePackets()
        {
            //Send to self
            QueuePacket(InventoryBeginChangePacket.BuildPacket(Id, true));
            myOfferings.SendUpdate(this);
            QueuePacket(InventoryEndChangePacket.BuildPacket(Id));

            //Send to other trader
            otherTrader.QueuePacket(InventoryBeginChangePacket.BuildPacket(Id, true));
            myOfferings.SendUpdateAsItemPackage(otherTrader);
            otherTrader.QueuePacket(InventoryEndChangePacket.BuildPacket(Id));
        }

        public void AcceptTrade(bool accepted)
        {
            if (!IsTrading())
                return;
            isTradeAccepted = accepted;
        }

        public void FinishTradeTransaction()
        {
            if (myOfferings != null)
            {
                myOfferings.ClearAll();
                for (ushort i = 0; i < myOfferings.GetCapacity(); i++)
                {
                    InventoryItem offeredItem = myOfferings.GetItemAtSlot(i);
                    if (offeredItem != null)
                        offeredItem.SetNormal();
                }

                QueuePacket(InventoryBeginChangePacket.BuildPacket(Id, true));
                myOfferings.SendUpdate(this);
                QueuePacket(InventoryEndChangePacket.BuildPacket(Id));
            }

            isTradeAccepted = false;
            myOfferings = null;
            otherTrader = null;
        }


        // Item recast per gamedata_items.recastGroup: every medicine shares one timer, food another.
        // Not saved across logout.
        private readonly Dictionary<byte, DateTime> itemRecastReady = new Dictionary<byte, DateTime>();

        public double GetItemRecastRemaining(byte recastGroup)
        {
            if (!itemRecastReady.TryGetValue(recastGroup, out DateTime ready))
                return 0;
            return Math.Max(0, (ready - DateTime.Now).TotalSeconds);
        }

        public void SetItemRecast(byte recastGroup, float seconds)
        {
            if (seconds > 0)
                itemRecastReady[recastGroup] = DateTime.Now.AddSeconds(seconds);
        }

        public void UseItem(ushort package, ushort slot)
        {
            UseItem(package, slot, null);
        }

        // Only scripted consumables act on the target the client sent; the rest are self only.
        public void UseItem(ushort package, ushort slot, Character target)
        {
            InventoryItem item = GetItemPackage(package)?.GetItemAtSlot(slot);
            if (item == null || !aiContainer.CanChangeState())
            {
                SendGameMessage(Server.GetWorldManager().GetActor(), ItemState.TEXT_CANNOT_USE_ITEM, 0x20, (object)(int)ItemState.COMMAND_USE_ITEM);
                return;
            }
            aiContainer.ChangeState(new ItemState(this, target ?? this, package, slot, item.itemId));
        }

        public bool UseItemById(uint itemId)
        {
            InventoryItem item = GetItemPackage(ItemPackage.NORMAL)?.GetItemByCatelogId(itemId);
            if (item == null)
                return false;
            UseItem(ItemPackage.NORMAL, item.slot);
            return true;
        }
    }
}
