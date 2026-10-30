require("Global")
require("Quest")
require("QuestDuty")
require("GcCompany")

--[[
Don't Hate the Messenger (Gcl105, one quest per company: 111431 / 111631 / 111831). After Gcl104.
Level 45, company rank 11. Shared functions take a3 = company.

 - Offer: the officer processEventStartLim / StartGri / StartUld (1 = accepted). Repeat
   processEventGuincum / Fulke / Aubrey.
 - SEQ_000 Kinnison (clearing before Stillglade Fane): processEventKinnison(2), 1 = into the Lotus
   Stand. There Kan-E-Senna processEventSenna01(2) -> SEQ_003.
 - SEQ_003 Cid processEventCid01(2) -> SEQ_005.
 - SEQ_005 Kan-E-Senna processEventSenna02(2): her missive (int4) -> SEQ_010.
 - SEQ_010 Cid processEventCid03(a3) -> SEQ_015. He sends the Immortal Flames to Ul'dah first, the
   others to Limsa, so SEQ_015 / SEQ_020 are the two city stops in that order.
 - Limsa stop: Zanthael (Admiral's Lift) processEventZanthael1, 1 = into the stateroom. Merlwyb
   processEventMerlwyb1(a3): her missive (int5). Exit push back to the lift.
 - Ul'dah stop: Mumutano processEventMumutano01, 1 = into the Fragrant Chamber. Raubahn
   processEventRaubahn1(a3): his missive (int6).
 - SEQ_025 the messenger at the last stop's door: Waguda (processEventWaguda2) for the Maelstrom and
   Twin Adder, Augustine (processEventAugustine2) for the Immortal Flames. 1 = leave -> SEQ_028. The
   hall's exit push plays the same lines, so the way out works without the talk.
 - SEQ_028 Cid SW of Camp Brittlebark (Mor Dhona): processEventCid05(2) -> SEQ_030.
 - SEQ_030 Cid asks to go: three elite Garleans at the downed warship (QuestDirectorGcl10501, which
   runs Gcg103's director class). Win: the strongbox key (int3) -> SEQ_035.
 - SEQ_035 the strongbox push at the wreck: processEventNq1(2, 0): the schematics (int2), the key
   gone -> SEQ_040. The wrong containers (processEventContainer) are not placed.
 - SEQ_040 Cid processEventCid07 -> SEQ_045.
 - SEQ_045 arrival push in the clearing before the Fane -> SEQ_050.
 - SEQ_050 Papalymo processEventPapalymo01(2), then processEventNq(2) -> the Lotus Stand -> SEQ_055.
   The other Scions are not placed.
 - SEQ_055 the company's leader (Kan-E-Senna Senna05 / Merlwyb Merlwyb3 / Raubahn Raubahn3) and Cid
   processEventCid09, both -> SEQ_060; the missives are handed over. Merlwyb3/4, Raubahn3/4,
   Eynzahr2/3 and Eline2/3 fill the Senna05/06 and Swethryk03/04 slots for the other companies.
 - SEQ_060 the company's marshal (Brookstone Swethryk04 / Eynzahr3 / Eline3) + rewards, then back out
   to the clearing.
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

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local company, co, ev = events(quest)
	local stop = stopAt(ev, sequence)

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

	if sequence >= SEQ_055 and classId == ev.leader then
		if sequence == SEQ_055 and not questFlag(quest, FLAG_SENNA05) then
			talk(ev.leaderFn)
			setFlag(quest, FLAG_SENNA05)
			councilDone(quest)
		else
			talk(ev.leaderAfter)
		end
		player:EndEvent()
		return
	end
	if sequence >= SEQ_055 and classId == ev.marshal then
		if sequence == SEQ_060 then
			talk(ev.marshalFn)
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
			return
		end
		talk(ev.marshalAfter)
		player:EndEvent()
		return
	end

	if stop ~= nil and classId == stop.guide then
		if talk(stop.guideFn) == 1 then
			-- The cutscene fades in after the warp into the hall.
			player:EndEvent()
			gcEnterHall(player, stop.hall)
			return
		end
		player:EndEvent()
		return
	end
	local lastStop = STOPS[ev.order[2]]
	if sequence == SEQ_025 and classId == lastStop.messengerNpc then
		if talk(lastStop.messenger, company) == 1 then
			quest:StartSequence(SEQ_028)
			player:EndEvent()
			gcLeaveHall(player, lastStop.hall)
			return
		end
		player:EndEvent()
		return
	end
	for key, s in pairs(STOPS) do
		if classId == s.leader and sequence >= SEQ_015 and sequence <= SEQ_025 then
			if stop == s then
				talk(s.leaderFn, company)
				quest:StartSequence(sequence == SEQ_015 and SEQ_020 or SEQ_025)
			else
				talk(s.repeatFn, company)
			end
			player:EndEvent()
			return
		elseif s.extras[classId] ~= nil then
			talk(s.extras[classId])
			player:EndEvent()
			return
		end
	end

	if classId == co.officer then
		talk(ev.officer)
	elseif classId == KINNISON then
		if talk("processEventKinnison", company) == 1 then
			player:EndEvent()
			gcEnterHall(player, "lotus")
			return
		end
	elseif classId == KANESENNA then
		if sequence == SEQ_000 then
			talk("processEventSenna01", company)
			quest:StartSequence(SEQ_003)
		elseif sequence == SEQ_005 then
			talk("processEventSenna02", company)
			quest:StartSequence(SEQ_010)
		elseif sequence >= SEQ_055 then
			talk("processEventSenna06")
		elseif sequence < SEQ_015 then
			talk("processEventSenna03")
		else
			talk("processEventSenna04")
		end
	elseif classId == CID then
		if sequence == SEQ_003 then
			talk("processEventCid01", company)
			quest:StartSequence(SEQ_005)
		elseif sequence == SEQ_005 then
			talk("processEventCid02")
		elseif sequence == SEQ_010 then
			talk("processEventCid03", company)
			quest:StartSequence(SEQ_015)
		elseif sequence == SEQ_015 then
			talk("processEventCid04", company)
		elseif sequence == SEQ_028 then
			talk("processEventCid05", company)
			quest:StartSequence(SEQ_030)
		elseif sequence == SEQ_030 then
			talk("processEventCid06")
			if talk("contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return
			end
		elseif sequence == SEQ_035 then
			talk("processEventCid06")
		elseif sequence == SEQ_040 then
			talk("processEventCid07")
			quest:StartSequence(SEQ_045)
		elseif sequence == SEQ_055 and not questFlag(quest, FLAG_CID09) then
			talk("processEventCid09")
			setFlag(quest, FLAG_CID09)
			councilDone(quest)
		elseif sequence >= SEQ_055 then
			talk("processEventCid10")
		else
			talk("processEventCid08")
		end
	elseif classId == PAPALYMO and sequence == SEQ_050 then
		talk("processEventPapalymo01", company)
		talk("processEventNq", company)	-- the council; fades in after the warp
		quest:StartSequence(SEQ_055)
		player:EndEvent()
		gcEnterHall(player, "lotus")
		return
	elseif classId == BROOKSTONE then
		if sequence >= SEQ_055 then
			talk("processEventSwethryk03")
		elseif sequence <= SEQ_005 then
			talk("processEventSwethryk01", company)
		else
			talk("processEventSwethryk02", company)
		end
	elseif classId == TEGOGO then
		talk(sequence >= SEQ_055 and "processEventTegogo1" or "processEventTegogo")
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
	local company, co, ev = events(quest)
	local hall = gcHallOfExit(classId)

	if hall ~= nil then
		-- At SEQ_025 the last hall's way out plays the messenger's lines.
		local last = STOPS[ev.order[2]]
		if sequence == SEQ_025 and hall == last.hall then
			local r = callClientFunction(player, "delegateEvent", player, quest, last.messenger, company)
			if r ~= 1 then
				player:EndEvent()
				return
			end
			quest:StartSequence(SEQ_028)
		end
		player:EndEvent()
		gcLeaveHall(player, hall)
		return
	elseif classId == STRONGBOX and sequence == SEQ_035 then
		callClientFunction(player, "delegateEvent", player, quest, "processEventNq1", company, 0)
		quest:StartSequence(SEQ_040)
	elseif classId == CLEARING_PUSH and sequence == SEQ_045 then
		quest:StartSequence(SEQ_050)
	end
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
