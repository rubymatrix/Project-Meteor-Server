require("Global")
require("Quest")
require("InstanceRaid")
require("GcCompany")

--[[
In for Garuda Wakening (Gcl104; 111430 / 111630 / 111830, one per company). Prereq: Gcl103 /
Gcg103 / Gcu103; level 45, company rank 11. Garuda is the lesser_garuda raid (InstanceRaid.lua).
Walkthrough: Data/Docs/Scripts/Quest/Gcl/Gcl104.md.
--]]

local questFlag

local SEQ_000 = 0	-- Investigate the winds at Quarrymill.
local SEQ_005 = 5	-- Report to Louisoix.
local SEQ_010 = 10	-- Defeat Garuda.
local SEQ_015 = 15	-- Report to Louisoix.
local SEQ_020 = 20	-- Meeting with Cid at the company's headquarters.
local SEQ_025 = 25	-- The leader awaits.
local SEQ_030 = 30	-- Claim the reward from the officer.

local LOUISOIX	= 1060022
local CID			= 1001572
local TEGOGO		= 1001916
local ETHELINDA	= 1001352
local DYRFHUND	= 1001921	-- the stateroom
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
	-- isSpawned: the public gc1_/gcs_ story actors exist only for players on this step.
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

local function nothing() end

local function talkEvent(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function louisoix04(player, quest, npc, company)
	talkEvent(player, quest, "processEventLouisoix04", company)
end

-- Officer, leader and council classes differ per Grand Company, so they can't be table keys.
local function companyTalk(player, quest, npc, company, co, ev)
	local classId = npc:GetActorClassId()
	local sequence = quest:GetSequence()
	if classId == co.officer then
		if sequence == SEQ_030 then
			-- a3 is the reward tier (2 adds the bonus-party line), the same tier as sqrwa
			local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
			talkEvent(player, quest, ev.officer03, tier)
			local rewarded = showQuestRewards(player, quest, tier)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest, tier) end
			return true
		end
		talkEvent(player, quest, ev.officer01)
	elseif classId == ev.sceneNpc and sequence == SEQ_025 then
		-- the scene ends in startFadeInCutSceneAfterWarp: into the leader's hall
		talkEvent(player, quest, ev.scene)
		quest:StartSequence(SEQ_030)
		player:EndEvent()
		gcEnterHall(player, co.hall)
		return true
	elseif ev.council[classId] ~= nil then
		talkEvent(player, quest, ev.council[classId])
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[LOUISOIX] = function(player, quest, npc, company)
			local accepted = talkEvent(player, quest, "processEventStart", 0, company, 1) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return true
		end,
		[ETHELINDA] = nothing,
		[CID] = nothing,
		other = nothing,
	},
	[SEQ_000] = {
		[LOUISOIX] = function(player, quest) talkEvent(player, quest, "processEventStartAfter") end,
	},
	[SEQ_005] = {
		[LOUISOIX] = function(player, quest)
			talkEvent(player, quest, "processEventLouisoix01")	-- answers ask 205 itself; both answers continue
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_010] = {
		[LOUISOIX] = function(player, quest) talkEvent(player, quest, "processEventLouisoix02") end,
	},
	[SEQ_015] = {
		[LOUISOIX] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventLouisoix03", company)
			quest:StartSequence(SEQ_020)
		end,
	},
	[SEQ_020] = {
		[CID] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventCid", company)
			quest:StartSequence(SEQ_025)
		end,
	},
	always = {
		[LOUISOIX] = louisoix04,
		[ETHELINDA] = function(player, quest) talkEvent(player, quest, "processEventEthelinda") end,
		[CID] = nothing,
	},
	other = companyTalk,
}

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local company, co = gcCompany(quest)
	if runQuestHandler(talk, player, quest, npc, company, co, COMPANY_EVENTS[company]) then return end
	player:EndEvent()
end

local push = {
	[SEQ_000] = {
		[QUARRYMILL_PUSH] = function(player, quest)
			talkEvent(player, quest, "processEventNQ")	-- gc010410, in place
			quest:StartSequence(SEQ_005)
		end,
	},
	other = function(player, quest, npc)
		local hall = gcHallOfExit(npc:GetActorClassId())
		if hall ~= nil then
			player:EndEvent()
			gcLeaveHall(player, hall)
			return true
		end
	end,
}

function onPush(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	if runQuestHandler(push, player, quest, npc) then return end
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
