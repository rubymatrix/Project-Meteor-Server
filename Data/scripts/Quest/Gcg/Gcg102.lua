require("Global")
require("Quest")
require("QuestDuty")

--[[
Two Vans are Better than One (Gcg102, 111627). Prereq: Gcg101; level 40, Twin Adder rank 11.
The Mist Emitter can't be used yet, and the Echo scene plays in place. No quest markers exist.
Walkthrough: Data/Docs/Scripts/Quest/Gcg/Gcg102.md.
--]]

local startDuty


local SEQ_000 = 0
local SEQ_001 = 1
local SEQ_002 = 2
local SEQ_003 = 3
local SEQ_004 = 4
local SEQ_005 = 5

local FULKE		= 1500200
local FLUTAINT	= 1001809	-- the client calls him Quinquerol
local YARBOROUGH	= 1001808	-- the client names this one Vevina
local ARTHUR		= 1001734
local PFRYMLOEF	= 1001812
local CID			= 1001572
local EBRELNAUX	= 1060011
local BARDO		= 1001580
local LIONNELLAIS	= 1500055

local DUTY_ZONE		= 151	-- East Shroud
local DUTY_AREA		= "SimpleContentGcg10201"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcg10201"
local DUTY_ANCHOR		= {1644.0, 45.1, -796.0, -1.2}
local SITE_RETURN		= {1644.0, 45.1, -796.0, -1.2}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(FULKE, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	quest:SetENpc(FULKE)
	if sequence <= SEQ_003 then
		local flutaintTalk = (sequence == SEQ_000 or sequence == SEQ_001 or sequence == SEQ_003)
		-- isSpawned: these story actors exist only for players on this quest.
		quest:SetENpc(FLUTAINT, flutaintTalk and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(PFRYMLOEF, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(ARTHUR, QFLAG_OFF, true, false, false, true)
		quest:SetENpc(YARBOROUGH, QFLAG_OFF, true, false, false, true)
	else
		quest:SetENpc(EBRELNAUX, sequence == SEQ_004 and QFLAG_TALK or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(CID, sequence == SEQ_005 and QFLAG_REWARD or QFLAG_OFF, true, false, false, true)
		quest:SetENpc(BARDO, QFLAG_OFF, true, false, false, true)
		quest:SetENpc(LIONNELLAIS)
	end
end

local function delegate(player, quest, fn, ...)
	callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function say(fn)
	return function(player, quest) delegate(player, quest, fn) end
end

local function notOffered() end

local talk = {
	-- Before the offer only Fulke answers; the others' always lines must not play.
	[SEQ_ACCEPT] = {
		[FULKE] = function(player, quest)
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return true
		end,
		[FLUTAINT] = notOffered,
		[PFRYMLOEF] = notOffered,
		[ARTHUR] = notOffered,
		[YARBOROUGH] = notOffered,
		[EBRELNAUX] = notOffered,
		[BARDO] = notOffered,
		[LIONNELLAIS] = notOffered,
		[CID] = notOffered,
	},
	[SEQ_000] = {
		[FLUTAINT] = function(player, quest)
			-- 0 plays the main path.
			delegate(player, quest, "processEventQuinquerol", 0)
			quest:StartSequence(SEQ_001)
		end,
		[ARTHUR] = say("processEventArthur"),
		[YARBOROUGH] = say("processEventVevina01"),
	},
	[SEQ_001] = {
		[FLUTAINT] = function(player, quest)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return true
			end
		end,
		[ARTHUR] = say("processEventArthur"),
		[YARBOROUGH] = say("processEventVevina01"),
	},
	[SEQ_002] = {
		[FLUTAINT] = say("processEventQuinquerolNQF"),
		[PFRYMLOEF] = function(player, quest)
			local r = callClientFunction(player, "delegateEvent", player, quest, "processEventPfrymloefNQF")
			if r == 1 or r == true then
				delegate(player, quest, "processEventPfrymloefNQ")
				quest:StartSequence(SEQ_003)
			end
		end,
		[ARTHUR] = say("processEventArthurNQF"),
		[YARBOROUGH] = say("processEventVevina02"),
	},
	[SEQ_003] = {
		[FLUTAINT] = function(player, quest)
			delegate(player, quest, "processEventQuinquerolNQA")
			quest:StartSequence(SEQ_004)
		end,
		[PFRYMLOEF] = say("processEventPfrymloefNQA"),
	},
	[SEQ_004] = {
		[EBRELNAUX] = function(player, quest)
			delegate(player, quest, "processEventEbrelnaux")
			quest:StartSequence(SEQ_005)
		end,
		[BARDO] = say("processEventBardo"),
	},
	[SEQ_005] = {
		[CID] = function(player, quest)
			delegate(player, quest, "processEventClear")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[FULKE] = say("processEventStartAfter"),
		[FLUTAINT] = say("processEventQuinquerolFragC"),
		[PFRYMLOEF] = say("processEventPfrymloef"),
		[ARTHUR] = say("processEventArthurNQA"),
		[YARBOROUGH] = say("processEventVevina03"),
		[EBRELNAUX] = say("processEventEbrelnauxAfter"),
		[BARDO] = say("processEventBardoAfter"),
		[LIONNELLAIS] = say("processEventLionnellais"),
		[CID] = say("processEventCid"),
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcg10201 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end
	if success then
		wait(2)
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	local held = (sequence >= SEQ_001 and sequence ~= SEQ_ACCEPT) and 1 or 0
	return held
end

function getJournalMapMarkerList(player, quest)
end
