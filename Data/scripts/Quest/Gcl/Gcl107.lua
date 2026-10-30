require("Global")
require("Quest")
require("QuestDuty")
require("InstanceRaid")
require("GcCompany")

--[[
To Kill a Raven (Gcl107; 111433 / 111633 / 111833, one per company). Prereq: Gcl106; level 45,
company rank 11. All three companies hold the council at the Lotus Stand; the player's own leader
drives the story and the others make small talk.
Walkthrough: Data/Docs/Scripts/Quest/Gcl/Gcl107.md.
--]]

local RAID_KEY = "lesserWhiteGeneral"

-- Sequence Numbers
local SEQ_000 = 0	-- Emergency council at the Lotus Stand.
local SEQ_005 = 5	-- Confirm the site SE of Camp Glory.
local SEQ_010 = 10	-- Report to the leader.
local SEQ_015 = 15	-- Cid can land a force.
local SEQ_020 = 20	-- Meet Cid at the airship landing.
local SEQ_025 = 25	-- Board via Serpent Private Hodder.
local SEQ_030 = 30	-- Ask Cid about your doubts.
local SEQ_035 = 35	-- Report to the Lotus Stand.

-- Actor Class Ids (officers, leaders, marshals: gc_company.lua)
local KINNISON	= GC_KINNISON
local CID			= 1001572
local HODDER		= 1002090	-- "Stewart"
local GLORY_PUSH	= 1090356	-- SE of Camp Glory (145)

-- The leaders at the council: their three functions (seq 0 / seq 10 / repeat), all taking a3 = company.
local LEADERS = {
	[GC_KANESENNA]	= { "processEventSenna01", "processEventSenna02", "processEventSenna03" },
	[GC_MERLWYB]	= { "processEventMerlwyb1", "processEventMerlwyb2", "processEventMerlwyb3" },
	[GC_RAUBAHN]	= { "processEventRaubahn1", "processEventRaubahn2", "processEventRaubahn3" },
}
-- The marshals' council talk (a3 = company).
local MARSHALS = {
	[GC_BROOKSTONE]	= "processEventSwethryk",
	[GC_EYNZAHR]	= "processEventEynzahr",
	[GC_ELINE]		= "processEventEline",
}

-- Per company: the officer's functions.
local COMPANY_EVENTS = {
	[GC_MAELSTROM]	= { start = "processEventStartLim", officer = "processEventGuincum" },
	[GC_TWINADDER]	= { start = "processEventStartGri", officer = "processEventFulke" },
	[GC_FLAMES]		= { start = "processEventStartUld", officer = "processEventAubrey" },
}

-- Quest data flags
local FLAG_BONUS	= 0

local LANDING_ZONE	= 155	-- Gridania airship landing (Cid, Hodder)

local function isOurs(quest)
	return gcCompanyOfQuestId(quest:GetQuestId()) ~= nil
end

local function inLotusStand(player)
	return gcHallOfPlayer(player) == "lotus"
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
	local company, co = gcCompany(quest)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(co.officer, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	local function on(cond) return cond and QFLAG_TALK or QFLAG_OFF end
	quest:SetENpc(co.officer)
	quest:SetENpc(KINNISON, on(sequence == SEQ_000 or sequence == SEQ_010))
	if sequence == SEQ_035 then
		quest:SetENpc(KINNISON, QFLAG_REWARD)
	end
	for classId, _ in pairs(LEADERS) do
		quest:SetENpc(classId, on(classId == co.leader and (sequence == SEQ_000 or sequence == SEQ_010)))
	end
	-- isSpawned: the public gc1_ story actors exist only for players on this step.
	quest:SetENpc(CID, on(sequence == SEQ_015 or sequence == SEQ_020 or sequence == SEQ_030), true, false, false,
		sequence >= SEQ_020 and sequence <= SEQ_030)
	for classId, _ in pairs(MARSHALS) do
		quest:SetENpc(classId)
	end
	quest:SetENpc(GC_HALLS.lotus.exitPush, QFLAG_OFF, false, true)
	quest:SetENpc(GLORY_PUSH, QFLAG_OFF, false, sequence == SEQ_005, false, sequence == SEQ_005)
	if sequence == SEQ_025 then
		quest:SetENpc(HODDER, QFLAG_TALK)
	end
end

local function delegate(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function officerTalk(player, quest, npc)
	local company, co = gcCompany(quest)
	if npc:GetActorClassId() == co.officer then
		delegate(player, quest, COMPANY_EVENTS[company].officer)
	end
end

local function kinnisonWarp(player, quest)
	local fn = (quest:GetSequence() >= SEQ_010) and "processEventKinnison02" or "processEventKinnison01"
	if delegate(player, quest, fn) == 1 then
		player:EndEvent()
		gcEnterHall(player, "lotus")
		return true
	end
end

-- Another company's leader answers with the same functions' small-talk branch.
local function leaderTalk(player, quest, npc)
	local company, co = gcCompany(quest)
	local classId = npc:GetActorClassId()
	local fns = LEADERS[classId]
	if classId == co.leader then
		delegate(player, quest, fns[3], company)
	else
		delegate(player, quest, fns[(quest:GetSequence() >= SEQ_010) and 2 or 1], company)
	end
end

local function leaderStep(step, nextSequence, cutscene)
	return function(player, quest, npc)
		local company, co = gcCompany(quest)
		local classId = npc:GetActorClassId()
		if classId ~= co.leader then
			leaderTalk(player, quest, npc)
			return
		end
		if cutscene ~= nil then
			delegate(player, quest, cutscene)
		end
		delegate(player, quest, LEADERS[classId][step], company)
		quest:StartSequence(nextSequence)
	end
end

local function cidSmallTalk(player, quest)
	delegate(player, quest, quest:GetSequence() < SEQ_015 and "processEventCid01" or "processEventCid02")
end

local function marshalTalk(player, quest, npc)
	local company = gcCompany(quest)
	delegate(player, quest, MARSHALS[npc:GetActorClassId()], company)
end

local talk = {
	[SEQ_000] = {},
	[SEQ_010] = {},
	[SEQ_015] = {
		[CID] = function(player, quest)
			if not inLotusStand(player) then
				cidSmallTalk(player, quest)
				return
			end
			-- a4 = the raid id for {sheet xtx/raidDungeon[int1]}
			delegate(player, quest, "processEventCid03", gcCompany(quest), 15)
			quest:StartSequence(SEQ_020)
		end,
	},
	[SEQ_020] = {
		[CID] = function(player, quest)
			if player.CurrentArea.ZoneId ~= LANDING_ZONE then
				cidSmallTalk(player, quest)
				return
			end
			delegate(player, quest, "processEventNq2", gcCompany(quest))	-- gc010714, mode 2
			quest:StartSequence(SEQ_025)
		end,
	},
	[SEQ_025] = {
		[HODDER] = function(player, quest)
			-- a3 = the raid id (xtx/raidDungeon[int1]); a4 = false: Rivenroad, not the Hard texts
			local r = callClientFunction(player, "delegateEvent", player, quest, "processEventStewart", 15, false)
			if r == 1 then
				local def = getInstanceRaid(RAID_KEY)
				local yes = callClientFunction(player, "askEnterInstanceRaid", def.contentId)
				player:EndEvent()
				if yes == true or yes == 1 then
					enterInstanceRaid(RAID_KEY, player)
				end
				return true
			end
		end,
	},
	[SEQ_030] = {
		[CID] = function(player, quest)
			delegate(player, quest, "processEventCid04", gcCompany(quest))
			quest:StartSequence(SEQ_035)
		end,
	},
	[SEQ_035] = {
		[KINNISON] = function(player, quest)
			if delegate(player, quest, "processEventKinnison03", gcCompany(quest)) == 1 then	-- gc010750 played on 1
				local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
				local rewarded = showQuestRewards(player, quest, tier)
				player:EndEvent()
				if rewarded then player:CompleteQuest(quest, tier) end
				return true
			end
		end,
	},
	always = {
		[KINNISON] = kinnisonWarp,
		[CID] = cidSmallTalk,
	},
	other = officerTalk,
}
for classId in pairs(LEADERS) do
	talk[SEQ_000][classId] = leaderStep(1, SEQ_005, "processEventNq1")	-- gc010710, the council
	talk[SEQ_010][classId] = leaderStep(2, SEQ_015)
	talk.always[classId] = leaderTalk
end
for classId in pairs(MARSHALS) do
	talk.always[classId] = marshalTalk
end

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end

	if quest:GetSequence() == SEQ_ACCEPT then
		local company, co = gcCompany(quest)
		if npc:GetActorClassId() == co.officer then
			local accepted = delegate(player, quest, COMPANY_EVENTS[company].start) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		end
		player:EndEvent()
		return
	end

	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
end

function onPush(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local classId = npc:GetActorClassId()
	local hall = gcHallOfExit(classId)
	if hall ~= nil then
		player:EndEvent()
		gcLeaveHall(player, hall)
		return
	elseif classId == GLORY_PUSH and quest:GetSequence() == SEQ_005 then
		-- gc010714, mode 2, plays in place.
		callClientFunction(player, "delegateEvent", player, quest, "processEventNq2", (gcCompany(quest)))
		quest:StartSequence(SEQ_010)
	end
	player:EndEvent()
end

-- The raid content on a win: Nael is dead.
function onRaidCleared(player, quest, director, bonus)
	if not isOurs(quest) or quest:GetSequence() ~= SEQ_025 then
		return
	end
	local data = quest:GetData()
	if bonus then data:SetFlag(FLAG_BONUS) else data:ClearFlag(FLAG_BONUS) end
	data:Save()
	quest:StartSequence(SEQ_030)
end

function getJournalInformation(player, quest)
end

local LEADER_MARKER = { [GC_MAELSTROM] = 11181606, [GC_TWINADDER] = 11181607, [GC_FLAMES] = 11181608 }

function getJournalMapMarkerList(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 or sequence == SEQ_035 then
		return 11181601							-- Kinnison
	elseif sequence == SEQ_005 then
		return 11181605							-- the site SE of Camp Glory
	elseif sequence == SEQ_010 then
		return 11181601, LEADER_MARKER[gcCompanyOfQuestId(quest:GetQuestId())]
	elseif sequence == SEQ_015 then
		return 11181609							-- Cid, Lotus Stand
	elseif sequence == SEQ_020 or sequence == SEQ_030 then
		return 11181613, 11181610					-- Cid at the airship landing
	elseif sequence == SEQ_025 then
		return 11181611, 11181612					-- Serpent Private Hodder
	end
end
