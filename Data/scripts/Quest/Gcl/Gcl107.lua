require("Global")
require("Quest")
require("QuestDuty")
require("InstanceRaid")
require("GcCompany")

--[[

Quest Script

Name: 	To Kill a Raven
Code: 	Gcl107 (client class for 111433 / 111633 / 111833)
Id: 	111433 / 111633 / 111833, one per company (gc_company.lua).
Prereq: Gcl106 (111432 / 111632 / 111832). Level 45, company rank 11.

Spec: decomp/docs/gridania_story_quests.md §0.6, §16.
 - Offer: the officer processEventStartLim / StartGri / StartUld (1 = accepted). Repeat
   processEventGuincum / Fulke / Aubrey.
 - All three companies hold the council at the Lotus Stand (spec §16): Kinnison's warps have no company
   branch, and each leader's function (Senna / Merlwyb / Raubahn, a3 = company) has a "my own company"
   branch and a small-talk branch. The player's own leader drives the story; the others make small talk.
 - SEQ_000 Kinnison processEventKinnison01, 1 = the Lotus Stand (206 private area 61, DESIGN). The leader
   there: processEventNq1 (gc010710, in place) then <Leader>1(a3) -> SEQ_005 [order: cutReplay].
 - SEQ_005 the site SE of Camp Glory (Coerthas Eastern Lowlands, push, DESIGN): processEventNq2(2)
   (gc010714, mode 2, in place) -> SEQ_010.
 - SEQ_010 Kinnison processEventKinnison02 -> the Lotus Stand; the leader <Leader>2(a3) -> SEQ_015.
 - SEQ_015 Cid (Lotus Stand) processEventCid03(2, 15) -> SEQ_020.
 - SEQ_020 Cid at the Gridania airship landing: processEventNq2(2) (gc010714 again) -> SEQ_025
   [inference: the second cutReplay entry; what a3 selects is open, spec §18.3].
 - SEQ_025 Serpent Private Hodder (InstanceRaidGuide): processEventStewart(15, false); 1 = board ->
   askEnterInstanceRaid(15) -> InstanceRaid.lua "lesser_white_general". A clear -> onRaidCleared -> SEQ_030.
 - SEQ_030 Cid (airship landing) processEventCid04(2) -> SEQ_035.
 - SEQ_035 Kinnison processEventKinnison03(2): 1 = gc010750 (Dalamud stays), then the rewards here
   (tier 2 for all three companies in the party at the clear) [inference: who turns in is open, §18.1].
Positions: seed_msq_gridania_30_gc.sql, seed_gc_story_shared.sql (DESIGN).

]]

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
	-- isSpawned: the public gc1_ story actors exist only for players on this step (server_eventnpc_quest_gated).
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
		if classId == co.officer then
			local accepted = talk(ev.start) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		end
		player:EndEvent()
		return
	end

	if classId == co.officer then
		talk(ev.officer)
	elseif classId == KINNISON then
		if sequence == SEQ_035 then
			if talk("processEventKinnison03", company) == 1 then	-- gc010750 played on 1
				local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
				local rewarded = showQuestRewards(player, quest, tier)
				player:EndEvent()
				if rewarded then player:CompleteQuest(quest, tier) end
				return
			end
		else
			local fn = (sequence >= SEQ_010) and "processEventKinnison02" or "processEventKinnison01"
			if talk(fn) == 1 then
				player:EndEvent()
				gcEnterHall(player, "lotus")
				return
			end
		end
	elseif LEADERS[classId] ~= nil then
		local fns = LEADERS[classId]
		if classId == co.leader and sequence == SEQ_000 then
			talk("processEventNq1")	-- gc010710, the council
			talk(fns[1], company)
			quest:StartSequence(SEQ_005)
		elseif classId == co.leader and sequence == SEQ_010 then
			talk(fns[2], company)
			quest:StartSequence(SEQ_015)
		elseif classId == co.leader then
			talk(fns[3], company)
		else
			-- another company's leader: the same functions' small-talk branch [inference: by step]
			talk(fns[(sequence >= SEQ_010) and 2 or 1], company)
		end
	elseif classId == CID then
		if sequence == SEQ_015 and inLotusStand(player) then
			-- a4 = the raid id for {sheet xtx/raidDungeon[int1]}
			talk("processEventCid03", company, 15)
			quest:StartSequence(SEQ_020)
		elseif sequence == SEQ_020 and player.CurrentArea.ZoneId == LANDING_ZONE then
			talk("processEventNq2", company)	-- gc010714, mode 2 (result unused: spec §18.3)
			quest:StartSequence(SEQ_025)
		elseif sequence == SEQ_030 then
			talk("processEventCid04", company)
			quest:StartSequence(SEQ_035)
		elseif sequence < SEQ_015 then
			talk("processEventCid01")
		else
			talk("processEventCid02")
		end
	elseif MARSHALS[classId] ~= nil then
		talk(MARSHALS[classId], company)
	elseif classId == HODDER and sequence == SEQ_025 then
		-- a3 = the raid id (xtx/raidDungeon[int1]); a4 = false: Rivenroad, not the Hard texts
		local r = callClientFunction(player, "delegateEvent", player, quest, "processEventStewart", 15, false)
		if r == 1 then
			local def = getInstanceRaid(RAID_KEY)
			local yes = callClientFunction(player, "askEnterInstanceRaid", def.contentId)
			player:EndEvent()
			if yes == true or yes == 1 then
				enterInstanceRaid(RAID_KEY, player)
			end
			return
		end
	end
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
		-- gc010714 (mode 2, in place); a3 [inference: company, as in Nq2's other calls]
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

-- Markers 111816 (client/docs/gc_quest_contracts.md §2.1).
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
