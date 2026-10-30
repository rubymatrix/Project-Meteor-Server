require("Global")
require("Quest")

--[[
Seeing the Seers (Etc3g0, 110674). Prereq: level 5, any class.
--]]

local seq000CheckCondition

local SEQ_000	= 0  -- Talk to all the seers.
local SEQ_001	= 1  -- Return to Kinnison.

local KINNISON 		= 1001430
local SYBELL 			= 1001437
local KHUMA_MOSHROCA	= 1001081
local NELLAURE 		= 1000821
local MESTONNAUX 		= 1001103
local LEFWYNE 		= 1001396

local MRKR_KINNISON		= 11080001
local MRKR_SYBELL			= 11080002
local MRKR_KHUMA_MOSHROCA	= 11080003
local MRKR_NELLAURE		= 11080004
local MRKR_MESTONNAUX		= 11080005
local MRKR_LEFWYNE		= 11080006

local FLAG_TALKED_MESTONNAUX 		= 0
local FLAG_TALKED_SYBELL 			= 1
local FLAG_TALKED_NELLAURE 		= 2
local FLAG_TALKED_KHUMA_MOSHROCA 	= 3
local FLAG_TALKED_LEFWYNE 		= 4

local COUNTER_TALKED              = 0

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(KINNISON, QFLAG_TALK)
	end

	local data = quest:GetData()
	if sequence == SEQ_000 then
		quest:SetENpc(KINNISON)
		quest:SetENpc(SYBELL,           (not data:GetFlag(FLAG_TALKED_SYBELL) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(KHUMA_MOSHROCA,   (not data:GetFlag(FLAG_TALKED_KHUMA_MOSHROCA) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(NELLAURE,         (not data:GetFlag(FLAG_TALKED_NELLAURE) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(MESTONNAUX,       (not data:GetFlag(FLAG_TALKED_MESTONNAUX) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(LEFWYNE,          (not data:GetFlag(FLAG_TALKED_LEFWYNE) and QFLAG_TALK or QFLAG_OFF))
	elseif sequence == SEQ_001 then
		quest:SetENpc(KINNISON, QFLAG_REWARD)
	end
end

local function offer(player, quest)
	if player:HasQuest(quest) then return false end
	local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventOffersStart")
	if questAccepted == 1 then
		player:AcceptQuest(quest)
	end
	player:EndEvent()
	return true
end

local function speakTo(flag, first, again)
	return function(player, quest)
		local data = quest:GetData()
		if data:GetFlag(flag) then
			callClientFunction(player, "delegateEvent", player, quest, again)
			return
		end
		callClientFunction(player, "delegateEvent", player, quest, first)
		data:SetFlag(flag)

		local counterAmount = data:IncCounter(COUNTER_TALKED)
		attentionMessage(player, 51061, 0, counterAmount, 5) -- You have heard word of the Seedseers. (... of 5)

		if seq000CheckCondition(data) then
			attentionMessage(player, 25225, quest:GetQuestId()) -- "Seeing the Seers" objectives complete!
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_001)
		end
	end
end

local talk = {
	[SEQ_000] = {
		[KINNISON] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEventOffersAfter")
		end,
		[SYBELL] = speakTo(FLAG_TALKED_SYBELL, "processEventSybellSpeak", "processEventSybellSpeakAfter"),
		[KHUMA_MOSHROCA] = speakTo(FLAG_TALKED_KHUMA_MOSHROCA, "processEventKhumaSpeak", "processEventKhumaSpeakAfter"),
		[NELLAURE] = speakTo(FLAG_TALKED_NELLAURE, "processEventNellaureSpeak", "processEventNellaureSpeakAfter"),
		[MESTONNAUX] = speakTo(FLAG_TALKED_MESTONNAUX, "processEventMestonnauxSpeak", "processEventMestonnauxSpeakAfter"),
		[LEFWYNE] = speakTo(FLAG_TALKED_LEFWYNE, "processEventLefwyneSpeak", "processEventLefwyneSpeakAfter"),
	},
	[SEQ_001] = {
		[KINNISON] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
	always = {
		[KINNISON] = offer,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function seq000CheckCondition(data)
	return (data:GetFlag(FLAG_TALKED_SYBELL) and
			data:GetFlag(FLAG_TALKED_KHUMA_MOSHROCA) and
			data:GetFlag(FLAG_TALKED_NELLAURE) and
			data:GetFlag(FLAG_TALKED_MESTONNAUX) and
			data:GetFlag(FLAG_TALKED_LEFWYNE))
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}
	local data = quest:GetData()

	if sequence == SEQ_000 then
		if not data:GetFlag(FLAG_TALKED_SYBELL) then table.insert(possibleMarkers, MRKR_SYBELL) end
		if not data:GetFlag(FLAG_TALKED_KHUMA_MOSHROCA) then table.insert(possibleMarkers, MRKR_KHUMA_MOSHROCA) end
		if not data:GetFlag(FLAG_TALKED_NELLAURE) then table.insert(possibleMarkers, MRKR_NELLAURE) end
		if not data:GetFlag(FLAG_TALKED_MESTONNAUX) then table.insert(possibleMarkers, MRKR_MESTONNAUX) end
		if not data:GetFlag(FLAG_TALKED_LEFWYNE) then table.insert(possibleMarkers, MRKR_LEFWYNE) end
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_KINNISON)
	end

	return unpack(possibleMarkers)
end