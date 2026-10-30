require("Global")
require("Quest")
require("QuestDuty")
require("GcCompany")

--[[
Don't Hate the Messenger (Gcl105; 111431 / 111631 / 111831, one per company). Prereq: Gcl104;
level 45, company rank 11. Two city stops in the company's order, a Garlean fight in Mor Dhona,
then the council at the Lotus Stand. Walkthrough: Data/Docs/Scripts/Quest/Gcl/Gcl105.md.
--]]

local councilDone, setFlag, questFlag, startDuty

local SEQ_000 = 0
local SEQ_003 = 3
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_028 = 28
local SEQ_030 = 30
local SEQ_035 = 35
local SEQ_040 = 40
local SEQ_045 = 45
local SEQ_050 = 50
local SEQ_055 = 55
local SEQ_060 = 60

local KINNISON	= GC_KINNISON
local KANESENNA	= GC_KANESENNA
local CID			= 1001572
local BROOKSTONE	= GC_BROOKSTONE	-- the client names this one Swethryk
local TEGOGO		= 1001916
local PAPALYMO	= 1002070
local ZANTHAEL	= GC_ZANTHAEL
local MERLWYB		= GC_MERLWYB
local EYNZAHR		= GC_EYNZAHR
local MUMUTANO	= GC_MUMUTANO
local RAUBAHN		= GC_RAUBAHN
local ELINE		= GC_ELINE
local STRONGBOX		= 1090354
local CLEARING_PUSH	= 1090355	-- before Stillglade Fane

local STOPS = {
	limsa = {
		hall = "stateroom", guide = ZANTHAEL, guideFn = "processEventZanthael1",
		leader = MERLWYB, leaderFn = "processEventMerlwyb1", repeatFn = "processEventMerlwyb2",
		extras = { [EYNZAHR] = "processEventEynzahr1" },
		messenger = "processEventAugustine2", messengerNpc = 1001952,	-- Augustine, the stateroom's door guard
	},
	uldah = {
		hall = "chamber", guide = MUMUTANO, guideFn = "processEventMumutano01",
		leader = RAUBAHN, leaderFn = "processEventRaubahn1", repeatFn = "processEventRaubahn2",
		extras = { [ELINE] = "processEventEline1" },
		messenger = "processEventWaguda2", messengerNpc = 1001914,	-- Waguda, the chamber's door guard
	},
}

local COMPANY_EVENTS = {
	[GC_MAELSTROM] = {
		start = "processEventStartLim", officer = "processEventGuincum",
		order = { "limsa", "uldah" },
		leader = MERLWYB, leaderFn = "processEventMerlwyb3", leaderAfter = "processEventMerlwyb4",
		marshal = EYNZAHR, marshalFn = "processEventEynzahr3", marshalAfter = "processEventEynzahr2",
	},
	[GC_TWINADDER] = {
		start = "processEventStartGri", officer = "processEventFulke",
		order = { "limsa", "uldah" },
		leader = KANESENNA, leaderFn = "processEventSenna05", leaderAfter = "processEventSenna06",
		marshal = BROOKSTONE, marshalFn = "processEventSwethryk04", marshalAfter = "processEventSwethryk03",
	},
	[GC_FLAMES] = {
		start = "processEventStartUld", officer = "processEventAubrey",
		order = { "uldah", "limsa" },
		leader = RAUBAHN, leaderFn = "processEventRaubahn3", leaderAfter = "processEventRaubahn4",
		marshal = ELINE, marshalFn = "processEventEline3", marshalAfter = "processEventEline2",
	},
}

local FLAG_SENNA05 = 0	-- the company's leader spoke at the council
local FLAG_CID09   = 1

local DUTY_ZONE		= 190	-- Mor Dhona
local DUTY_AREA		= "SimpleContentGcl10501"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcl10501"
local DUTY_ANCHOR		= {-511.7, -4.79, 367.8, -2.98}
local WRECK_RETURN	= {-511.7, -4.79, 367.8, -2.98}

local function isOurs(quest)
	return gcCompanyOfQuestId(quest:GetQuestId()) ~= nil
end

local function events(quest)
	local company, co = gcCompany(quest)
	return company, co, COMPANY_EVENTS[company]
end

local function stopAt(ev, sequence)
	if sequence == SEQ_015 then
		return STOPS[ev.order[1]]
	elseif sequence == SEQ_020 then
		return STOPS[ev.order[2]]
	end
	return nil
end

local function stopSeq(ev, key)
	return (ev.order[1] == key) and SEQ_015 or SEQ_020
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
	local company, co, ev = events(quest)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(co.officer, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	local function on(cond) return cond and QFLAG_TALK or QFLAG_OFF end
	local leaderPending = (sequence == SEQ_055 and not questFlag(quest, FLAG_SENNA05))

	quest:SetENpc(co.officer)
	quest:SetENpc(KINNISON, on(sequence == SEQ_000))
	quest:SetENpc(KANESENNA, on(sequence == SEQ_000 or sequence == SEQ_005 or (leaderPending and ev.leader == KANESENNA)))
	-- isSpawned: this Cid exists only for players on these steps.
	quest:SetENpc(CID, on(sequence == SEQ_003 or sequence == SEQ_010 or sequence == SEQ_028 or sequence == SEQ_030
		or sequence == SEQ_040 or (sequence == SEQ_055 and not questFlag(quest, FLAG_CID09))), true, false, false,
		sequence >= SEQ_028 and sequence <= SEQ_045)
	quest:SetENpc(BROOKSTONE, (sequence == SEQ_060 and ev.marshal == BROOKSTONE) and QFLAG_REWARD or QFLAG_OFF)
	quest:SetENpc(TEGOGO)
	quest:SetENpc(GC_HALLS.lotus.exitPush, QFLAG_OFF, false, true)
	if sequence >= SEQ_015 and sequence <= SEQ_025 then
		for key, stop in pairs(STOPS) do
			local here = (sequence == stopSeq(ev, key))
			quest:SetENpc(stop.guide, on(here))
			quest:SetENpc(stop.leader, on(here))
			for classId, _ in pairs(stop.extras) do
				quest:SetENpc(classId)
			end
			local last = STOPS[ev.order[2]] == stop
			quest:SetENpc(stop.messengerNpc, on(last and sequence == SEQ_025))
			quest:SetENpc(GC_HALLS[stop.hall].exitPush, QFLAG_OFF, false, true)
		end
	end
	if sequence >= SEQ_055 and ev.leader ~= KANESENNA then
		quest:SetENpc(ev.leader, on(leaderPending))
	end
	if sequence >= SEQ_055 and ev.marshal ~= BROOKSTONE then
		quest:SetENpc(ev.marshal, sequence == SEQ_060 and QFLAG_REWARD or QFLAG_OFF)
	end
	quest:SetENpc(STRONGBOX, QFLAG_OFF, false, sequence == SEQ_035, false, sequence == SEQ_035)
	quest:SetENpc(CLEARING_PUSH, QFLAG_OFF, false, sequence == SEQ_045, false, sequence == SEQ_045)
	if sequence >= SEQ_050 then
		quest:SetENpc(PAPALYMO, on(sequence == SEQ_050), true, false, false, true)
	end
end

local function nothing() end

local function talkEvent(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function leaderTalk(player, quest, sequence, ev)
	if sequence == SEQ_055 and not questFlag(quest, FLAG_SENNA05) then
		talkEvent(player, quest, ev.leaderFn)
		setFlag(quest, FLAG_SENNA05)
		councilDone(quest)
	else
		talkEvent(player, quest, ev.leaderAfter)
	end
	player:EndEvent()
	return true
end

local function marshalTalk(player, quest, sequence, ev)
	if sequence == SEQ_060 then
		talkEvent(player, quest, ev.marshalFn)
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then
			player:CompleteQuest(quest)
			-- The Lotus Stand's exit push belongs to the quest, so leave the hall here.
			local hall = gcHallOfPlayer(player)
			if hall ~= nil then
				gcLeaveHall(player, hall)
			end
		end
		return true
	end
	talkEvent(player, quest, ev.marshalAfter)
	player:EndEvent()
	return true
end

-- Officer, leader, marshal and city-stop classes differ per Grand Company, so they can't be table keys.
local function companyTalk(player, quest, npc, company, co, ev)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local stop = stopAt(ev, sequence)
	if sequence >= SEQ_055 and classId == ev.leader then
		return leaderTalk(player, quest, sequence, ev)
	end
	if sequence >= SEQ_055 and classId == ev.marshal then
		return marshalTalk(player, quest, sequence, ev)
	end
	if stop ~= nil and classId == stop.guide then
		if talkEvent(player, quest, stop.guideFn) == 1 then
			-- The cutscene fades in after the warp into the hall.
			player:EndEvent()
			gcEnterHall(player, stop.hall)
			return true
		end
		player:EndEvent()
		return true
	end
	local lastStop = STOPS[ev.order[2]]
	if sequence == SEQ_025 and classId == lastStop.messengerNpc then
		if talkEvent(player, quest, lastStop.messenger, company) == 1 then
			quest:StartSequence(SEQ_028)
			player:EndEvent()
			gcLeaveHall(player, lastStop.hall)
			return true
		end
		player:EndEvent()
		return true
	end
	for _, s in pairs(STOPS) do
		if classId == s.leader and sequence >= SEQ_015 and sequence <= SEQ_025 then
			if stop == s then
				talkEvent(player, quest, s.leaderFn, company)
				quest:StartSequence(sequence == SEQ_015 and SEQ_020 or SEQ_025)
			else
				talkEvent(player, quest, s.repeatFn, company)
			end
			player:EndEvent()
			return true
		elseif s.extras[classId] ~= nil then
			talkEvent(player, quest, s.extras[classId])
			player:EndEvent()
			return true
		end
	end
	if classId == co.officer then
		talkEvent(player, quest, ev.officer)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[KINNISON] = nothing,
		[KANESENNA] = nothing,
		[CID] = nothing,
		[BROOKSTONE] = nothing,
		[TEGOGO] = nothing,
		other = function(player, quest, npc, company, co, ev)
			if npc:GetActorClassId() == co.officer then
				local accepted = talkEvent(player, quest, ev.start) == 1
				player:EndEvent()
				if accepted then
					player:AcceptQuest(quest)
				end
				return true
			end
		end,
	},
	[SEQ_000] = {
		[KANESENNA] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventSenna01", company)
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[CID] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventCid01", company)
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[KANESENNA] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventSenna02", company)
			quest:StartSequence(SEQ_010)
		end,
		[CID] = function(player, quest) talkEvent(player, quest, "processEventCid02") end,
	},
	[SEQ_010] = {
		[CID] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventCid03", company)
			quest:StartSequence(SEQ_015)
		end,
	},
	[SEQ_015] = {
		[CID] = function(player, quest, npc, company) talkEvent(player, quest, "processEventCid04", company) end,
	},
	[SEQ_028] = {
		[CID] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventCid05", company)
			quest:StartSequence(SEQ_030)
		end,
	},
	[SEQ_030] = {
		[CID] = function(player, quest)
			talkEvent(player, quest, "processEventCid06")
			if talkEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return true
			end
		end,
	},
	[SEQ_035] = {
		[CID] = function(player, quest) talkEvent(player, quest, "processEventCid06") end,
	},
	[SEQ_040] = {
		[CID] = function(player, quest)
			talkEvent(player, quest, "processEventCid07")
			quest:StartSequence(SEQ_045)
		end,
	},
	[SEQ_050] = {
		[PAPALYMO] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventPapalymo01", company)
			talkEvent(player, quest, "processEventNq", company)	-- the council; fades in after the warp
			quest:StartSequence(SEQ_055)
			player:EndEvent()
			gcEnterHall(player, "lotus")
			return true
		end,
	},
	[SEQ_055] = {
		[CID] = function(player, quest)
			if questFlag(quest, FLAG_CID09) then
				talkEvent(player, quest, "processEventCid10")
				return
			end
			talkEvent(player, quest, "processEventCid09")
			setFlag(quest, FLAG_CID09)
			councilDone(quest)
		end,
	},
	always = {
		[KINNISON] = function(player, quest, npc, company)
			if talkEvent(player, quest, "processEventKinnison", company) == 1 then
				player:EndEvent()
				gcEnterHall(player, "lotus")
				return true
			end
		end,
		[KANESENNA] = function(player, quest, npc, company, co, ev)
			local sequence = quest:GetSequence()
			if sequence >= SEQ_055 and ev.leader == KANESENNA then
				return leaderTalk(player, quest, sequence, ev)
			elseif sequence >= SEQ_055 then
				talkEvent(player, quest, "processEventSenna06")
			elseif sequence < SEQ_015 then
				talkEvent(player, quest, "processEventSenna03")
			else
				talkEvent(player, quest, "processEventSenna04")
			end
		end,
		[CID] = function(player, quest)
			talkEvent(player, quest, quest:GetSequence() >= SEQ_055 and "processEventCid10" or "processEventCid08")
		end,
		[BROOKSTONE] = function(player, quest, npc, company, co, ev)
			local sequence = quest:GetSequence()
			if sequence >= SEQ_055 and ev.marshal == BROOKSTONE then
				return marshalTalk(player, quest, sequence, ev)
			elseif sequence >= SEQ_055 then
				talkEvent(player, quest, "processEventSwethryk03")
			elseif sequence <= SEQ_005 then
				talkEvent(player, quest, "processEventSwethryk01", company)
			else
				talkEvent(player, quest, "processEventSwethryk02", company)
			end
		end,
		[TEGOGO] = function(player, quest)
			talkEvent(player, quest, quest:GetSequence() >= SEQ_055 and "processEventTegogo1" or "processEventTegogo")
		end,
	},
	other = companyTalk,
}

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local company, co, ev = events(quest)
	if runQuestHandler(talk, player, quest, npc, company, co, ev) then return end
	player:EndEvent()
end

local push = {
	[SEQ_035] = {
		[STRONGBOX] = function(player, quest, npc, company)
			talkEvent(player, quest, "processEventNq1", company, 0)
			quest:StartSequence(SEQ_040)
		end,
	},
	[SEQ_045] = {
		[CLEARING_PUSH] = function(player, quest) quest:StartSequence(SEQ_050) end,
	},
	other = function(player, quest, npc, company, ev)
		local hall = gcHallOfExit(npc:GetActorClassId())
		if hall == nil then
			return
		end
		-- At SEQ_025 the last hall's way out plays the messenger's lines.
		local last = STOPS[ev.order[2]]
		if quest:GetSequence() == SEQ_025 and hall == last.hall then
			if talkEvent(player, quest, last.messenger, company) ~= 1 then
				player:EndEvent()
				return true
			end
			quest:StartSequence(SEQ_028)
		end
		player:EndEvent()
		gcLeaveHall(player, hall)
		return true
	end,
}

function onPush(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local company, _, ev = events(quest)
	if runQuestHandler(push, player, quest, npc, company, ev) then return end
	player:EndEvent()
end

function councilDone(quest)
	if questFlag(quest, FLAG_SENNA05) and questFlag(quest, FLAG_CID09) then
		quest:StartSequence(SEQ_060)
	else
		quest:UpdateENPCs()
	end
end

function setFlag(quest, flag)
	local data = quest:GetData()
	data:SetFlag(flag)
	data:Save()
end

function questFlag(quest, flag)
	local data = quest:GetData()
	return data ~= nil and data:GetFlag(flag)
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcl10501 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if not isOurs(quest) or quest:GetSequence() ~= SEQ_030 then
		return
	end
	if success then
		wait(2)
		quest:StartSequence(SEQ_035)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		endQuestDuty(player, duty, DUTY_ZONE, WRECK_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, WRECK_RETURN)
end

function getJournalInformation(player, quest)
	if not isOurs(quest) then
		return
	end
	local _, _, ev = events(quest)
	local s = quest:GetSequence()
	local function after(key) return (s > stopSeq(ev, key) and s < SEQ_060) and 1 or 0 end
	local schematics = (s >= SEQ_040) and 1 or 0
	local key = (s == SEQ_035) and 1 or 0
	local senna = (s >= SEQ_010 and s < SEQ_060) and 1 or 0
	return schematics, key, senna, after("limsa"), after("uldah")
end

local STOP_MARKERS = {
	limsa = { guide = 11181404, leader = 11181405, messenger = 11181406 },	-- Zanthael, Merlwyb, Augustine
	uldah = { guide = 11181407, leader = 11181408, messenger = 11181409 },	-- Mumutano, Raubahn, Waguda
}
local COUNCIL_MARKERS = {
	[GC_TWINADDER]	= { 11181418, 11181419 },	-- Cid, Kan-E-Senna (Lotus Stand)
	[GC_MAELSTROM]	= { 11181421, 11181422 },	-- Cid, Merlwyb (the clearing)
	[GC_FLAMES]		= { 11181424, 11181425 },	-- Cid, Raubahn (the clearing)
}
local MARSHAL_MARKER = { [GC_TWINADDER] = 11181420, [GC_MAELSTROM] = 11181423, [GC_FLAMES] = 11181426 }

function getJournalMapMarkerList(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	local company, co, ev = events(quest)
	if sequence == SEQ_000 then
		return 11181401							-- Kinnison
	elseif sequence == SEQ_003 or sequence == SEQ_010 then
		return 11181402							-- Cid, Lotus Stand
	elseif sequence == SEQ_005 then
		return 11181403							-- Kan-E-Senna
	elseif sequence == SEQ_015 or sequence == SEQ_020 then
		local m = STOP_MARKERS[ev.order[sequence == SEQ_015 and 1 or 2]]
		return m.guide, m.leader
	elseif sequence == SEQ_025 then
		return STOP_MARKERS[ev.order[2]].messenger
	elseif sequence == SEQ_028 or sequence == SEQ_030 or sequence == SEQ_040 then
		return 11181411, 11181410					-- Cid in Mor Dhona, his camp
	elseif sequence == SEQ_035 then
		return 11181413, 11181412					-- the wreck
	elseif sequence == SEQ_045 then
		return 11181414							-- the clearing before the Fane
	elseif sequence == SEQ_050 then
		return 11181416							-- Papalymo
	elseif sequence == SEQ_055 then
		return unpack(COUNCIL_MARKERS[company])
	elseif sequence == SEQ_060 then
		return MARSHAL_MARKER[company]
	end
end
