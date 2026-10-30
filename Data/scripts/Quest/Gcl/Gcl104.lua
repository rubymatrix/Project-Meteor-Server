require("Global")
require("Quest")
require("InstanceRaid")
require("GcCompany")

local questFlag

--[[

Quest Script

Name: 	In for Garuda Wakening
Code: 	Gcl104 (client class for 111430 / 111630 / 111830)
Id: 	111430 / 111630 / 111830, one per company (gc_company.lua).
Prereq: Gcl103 (111429) / Gcg103 (111629) / Gcu103 (111829). Level 45, company rank 11.

Spec: decomp/docs/gridania_story_quests.md §0.6, §13.
 - Offer: Louisoix at Apkallus Falls, processEventStart(0, 2, 1) (1 = accepted). a4 = 2 the Twin Adder
   line 275 [inference: company]; a5 = 1 "you beat Ifrit" (Gcg101 is a prerequisite; the moogle king
   half is not tracked) [inference]. Repeat processEventStartAfter.
 - SEQ_000 Quarrymill (South Shroud): push at the scene -> processEventNQ (gc010410, in place), int2
   Vortex Feather -> SEQ_005. Ethelinda processEventEthelinda.
 - SEQ_005 Louisoix processEventLouisoix01 (the Vortex Catcher: int3) -> SEQ_010. Repeat Louisoix02.
 - SEQ_010 the beastman aetheryte NE of Feathergorge (AetheryteBeastChildGuide, zone 143):
   askEnterInstanceRaid(12) -> InstanceRaid.lua "lesser_garuda". A clear -> onRaidCleared -> SEQ_015.
 - SEQ_015 Louisoix processEventLouisoix03(2) -> SEQ_020. Repeat Louisoix04(2).
 - SEQ_020 Cid in the company's headquarters processEventCid(a3) -> SEQ_025. The officer
   processEvent<Officer>01.
 - SEQ_025 the leader's scene, fade-in after warp into their hall (gc_company.lua GC_HALLS) -> SEQ_030:
   Twin Adder: Kan-E-Senna before Stillglade Fane, processEventNQG (gc01g410) -> the Lotus Stand.
   Maelstrom: Zanthael at the Admiral's Lift, processEventZanthael (elv0l110 + gc01l410) -> the stateroom.
   Immortal Flames: processEventNQU (gc01u410) -> the Fragrant Chamber; the client names no NPC for it,
   so Mumutano at the chamber door owns it [DESIGN].
 - SEQ_030 in the hall: the council NPCs talk (Senna / Swethryk / Tegogo; Merwyb / Eynzahr; Raubahn /
   Eline, plus Dyrfhund / Z'toldha / Augustine and Waguda); the way out is the exit push. The officer
   processEvent<Officer>03(a3): a3 is the reward tier, not the company (2 adds the bonus line); rewards at
   that tier (2 for a party all of the player's company at the clear). Nimie and Roric have no confirmed
   class (best fits only, client/docs/gc_quest_contracts.md §7) and are not placed.
Markers 111813 (the Maelstrom-side spots: Louisoix, Quarrymill, the Coerthas spot, Cid in Maelstrom
Command, Zanthael, Guincum); the other companies get the shared ones only.
Positions: seed_msq_gridania_30_gc.sql, seed_gc_story_shared.sql (DESIGN).

]]

-- Sequence Numbers
local SEQ_000 = 0	-- Investigate the winds at Quarrymill.
local SEQ_005 = 5	-- Report to Louisoix.
local SEQ_010 = 10	-- Defeat Garuda.
local SEQ_015 = 15	-- Report to Louisoix.
local SEQ_020 = 20	-- Meeting with Cid at the company's headquarters.
local SEQ_025 = 25	-- The leader awaits.
local SEQ_030 = 30	-- Claim the reward from the officer.

-- Actor Class Ids (officers and leaders: gc_company.lua)
local LOUISOIX	= 1060022
local CID			= 1001572
local TEGOGO		= 1001916
local ETHELINDA	= 1001352
local DYRFHUND	= 1001921	-- the stateroom (client/docs/gc_quest_contracts.md §7)
local TOLDHA		= 1001927	-- Z'toldha, the stateroom
local AUGUSTINE	= 1001952	-- "Storm Captain", the stateroom door
local WAGUDA		= 1001914	-- "Second Flame Commander", the chamber door
local QUARRYMILL_PUSH	= 1090350	-- the scene at Quarrymill (154)

-- Per company: the officer's functions, who plays the leader's scene at SEQ_025 and its function, and
-- the hall's talk at SEQ_030 by actor class.
local COMPANY_EVENTS = {
	[GC_MAELSTROM] = {
		officer01 = "processEventGuincum01", officer03 = "processEventGuincum03",
		sceneNpc = GC_ZANTHAEL, scene = "processEventZanthael",
		council = { [GC_MERLWYB] = "processEventMerwyb", [GC_EYNZAHR] = "processEventEynzahr",
			[DYRFHUND] = "processEventDyrfhund", [TOLDHA] = "processEventToldha",
			[AUGUSTINE] = "processEventAugustine" },
	},
	[GC_TWINADDER] = {
		officer01 = "processEventFulke01", officer03 = "processEventFulke03",
		sceneNpc = GC_KANESENNA, scene = "processEventNQG",	-- gc01g410, mode 2
		council = { [GC_KANESENNA] = "processEventSenna", [GC_BROOKSTONE] = "processEventSwethryk",
			[TEGOGO] = "processEventTegogo" },
	},
	[GC_FLAMES] = {
		officer01 = "processEventAubrey01", officer03 = "processEventAubrey03",
		sceneNpc = GC_MUMUTANO, scene = "processEventNQU",		-- gc01u410
		council = { [GC_RAUBAHN] = "processEventRaubahn", [GC_ELINE] = "processEventEline",
			[WAGUDA] = "processEventWaguda" },
	},
}

-- Quest data flags
local FLAG_BONUS = 0

local function isOurs(quest)
	return gcCompanyOfQuestId(quest:GetQuestId()) ~= nil
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if not isOurs(quest) then
		return
	end
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LOUISOIX, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	local company, co = gcCompany(quest)
	local ev = COMPANY_EVENTS[company]
	local louisoixTalk = (sequence == SEQ_005 or sequence == SEQ_015)
	quest:SetENpc(LOUISOIX, louisoixTalk and QFLAG_TALK or QFLAG_OFF)
	quest:SetENpc(co.officer, sequence == SEQ_030 and QFLAG_REWARD or QFLAG_OFF)
	quest:SetENpc(ETHELINDA)
	-- isSpawned: the public gc1_/gcs_ story actors exist only for players on this step (server_eventnpc_quest_gated).
	quest:SetENpc(QUARRYMILL_PUSH, QFLAG_OFF, false, sequence == SEQ_000, false, sequence == SEQ_000)
	if sequence >= SEQ_020 then
		quest:SetENpc(CID, sequence == SEQ_020 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	end
	if sequence >= SEQ_025 then
		quest:SetENpc(ev.sceneNpc, sequence == SEQ_025 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
	end
	if sequence == SEQ_030 then
		for classId, _ in pairs(ev.council) do
			if classId ~= ev.sceneNpc then
				quest:SetENpc(classId)
			end
		end
		quest:SetENpc(GC_HALLS[co.hall].exitPush, QFLAG_OFF, false, true)
	end
end

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local company, co = gcCompany(quest)
	local ev = COMPANY_EVENTS[company]

	local function talk(fn, ...)
		return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if sequence == SEQ_ACCEPT then
		if classId == LOUISOIX then
			local accepted = talk("processEventStart", 0, company, 1) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		end
		player:EndEvent()
		return
	end

	if classId == LOUISOIX then
		if sequence == SEQ_000 then
			talk("processEventStartAfter")
		elseif sequence == SEQ_005 then
			talk("processEventLouisoix01")	-- answers ask 205 itself; both answers continue
			quest:StartSequence(SEQ_010)
		elseif sequence == SEQ_010 then
			talk("processEventLouisoix02")
		elseif sequence == SEQ_015 then
			talk("processEventLouisoix03", company)
			quest:StartSequence(SEQ_020)
		else
			talk("processEventLouisoix04", company)
		end
	elseif classId == ETHELINDA then
		talk("processEventEthelinda")
	elseif classId == CID then
		if sequence == SEQ_020 then
			talk("processEventCid", company)
			quest:StartSequence(SEQ_025)
		end
	elseif classId == co.officer then
		if sequence == SEQ_030 then
			-- a3 is the reward tier (2 adds the bonus-party line), the same tier as sqrwa
			local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
			talk(ev.officer03, tier)
			local rewarded = showQuestRewards(player, quest, tier)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest, tier) end
			return
		end
		talk(ev.officer01)
	elseif classId == ev.sceneNpc and sequence == SEQ_025 then
		-- the scene ends in startFadeInCutSceneAfterWarp: into the leader's hall
		talk(ev.scene)
		quest:StartSequence(SEQ_030)
		player:EndEvent()
		gcEnterHall(player, co.hall)
		return
	elseif ev.council[classId] ~= nil then
		talk(ev.council[classId])
	end
	player:EndEvent()
end

function onPush(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if classId == QUARRYMILL_PUSH and sequence == SEQ_000 then
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ")	-- gc010410, in place
		quest:StartSequence(SEQ_005)
	elseif gcHallOfExit(classId) ~= nil then
		player:EndEvent()
		gcLeaveHall(player, gcHallOfExit(classId))
		return
	end
	player:EndEvent()
end

-- The raid content on a win: Garuda is beaten.
function onRaidCleared(player, quest, director, bonus)
	if not isOurs(quest) or quest:GetSequence() ~= SEQ_010 then
		return
	end
	local data = quest:GetData()
	if bonus then data:SetFlag(FLAG_BONUS) else data:ClearFlag(FLAG_BONUS) end
	data:Save()
	quest:StartSequence(SEQ_015)
end

function questFlag(quest, flag)
	local data = quest:GetData()
	return data ~= nil and data:GetFlag(flag)
end

-- int2 Vortex Feather (after the Quarrymill scene), int3 Vortex Catcher (from Louisoix until the clear)
function getJournalInformation(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	return (sequence == SEQ_005) and 1 or 0, (sequence == SEQ_010) and 1 or 0
end

local MRKR_LOUISOIX		= 11181301
local MRKR_QUARRYMILL		= 11181302
local MRKR_FEATHERGORGE	= 11181303
local MRKR_HQ				= 11181304
local MRKR_CID			= 11181305
local MRKR_ZANTHAEL		= 11181306
local MRKR_GUINCUM		= 11181307

function getJournalMapMarkerList(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	local limsa = gcCompanyOfQuestId(quest:GetQuestId()) == GC_MAELSTROM
	if sequence == SEQ_000 then
		return MRKR_QUARRYMILL
	elseif sequence == SEQ_005 or sequence == SEQ_015 then
		return MRKR_LOUISOIX
	elseif sequence == SEQ_010 then
		return MRKR_FEATHERGORGE
	elseif not limsa then
		return
	elseif sequence == SEQ_020 then
		return MRKR_CID, MRKR_HQ
	elseif sequence == SEQ_025 then
		return MRKR_ZANTHAEL
	elseif sequence == SEQ_030 then
		return MRKR_GUINCUM
	end
end
