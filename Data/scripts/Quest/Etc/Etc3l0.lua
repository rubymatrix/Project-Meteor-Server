require("Global")
require("Quest")

--[[
The Tug of the Whorl (Etc3l0, 110653). Prereq: level 5, any class.
--]]

local seq000CheckCondition

local SEQ_000	= 0  -- Talk to all the citizens.
local SEQ_001	= 1  -- Return to Ginnade.

local GINNADE 		= 1000132
local ZONGGO			= 1000057
local WHAHTOA			= 1000475
local FERDILLAIX 		= 1000344
local FRAILOISE 		= 1000065
local ARNEGIS 		= 1000227

local MRKR_ZONGGO			= 11070001
local MRKR_WHAHTOA		= 11070002
local MRKR_FERDILLAIX		= 11070003
local MRKR_FRAILOISE		= 11070004
local MRKR_ARNEGIS		= 11070005
local MRKR_GINNADE		= 11070006

local FLAG_TALKED_ZONGGO 			= 0
local FLAG_TALKED_WHAHTOA 		= 1
local FLAG_TALKED_FERDILLAIX 		= 2
local FLAG_TALKED_FRAILOISE	 	= 3
local FLAG_TALKED_ARNEGIS 		= 4

local COUNTER_TALKED              = 0

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(GINNADE, QFLAG_TALK)
	end

	local data = quest:GetData()
	if sequence == SEQ_000 then
		quest:SetENpc(GINNADE)
		quest:SetENpc(ZONGGO,     	(not data:GetFlag(FLAG_TALKED_ZONGGO) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(WHAHTOA,		(not data:GetFlag(FLAG_TALKED_WHAHTOA) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(FERDILLAIX,   (not data:GetFlag(FLAG_TALKED_FERDILLAIX) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(FRAILOISE,    (not data:GetFlag(FLAG_TALKED_FRAILOISE) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(ARNEGIS,      (not data:GetFlag(FLAG_TALKED_ARNEGIS) and QFLAG_TALK or QFLAG_OFF))
	elseif sequence == SEQ_001 then
		quest:SetENpc(GINNADE, QFLAG_REWARD)
	end
end

local function offer(player, quest)
	if player:HasQuest(quest) then return false end
	local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGinnadeStart")
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
		attentionMessage(player, 51060, 0, counterAmount, 5) -- You have spoken with a Barracuda informant. (... of 5)

		if seq000CheckCondition(data) then
			attentionMessage(player, 25225, quest:GetQuestId()) -- "The Tug of the Whorl" objectives complete!
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_001)
		end
	end
end

local talk = {
	[SEQ_000] = {
		[GINNADE] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "followEvent005")
		end,
		[ZONGGO] = speakTo(FLAG_TALKED_ZONGGO, "processEvent010", "followEvent010"),
		[WHAHTOA] = speakTo(FLAG_TALKED_WHAHTOA, "processEvent020", "followEvent020"),
		[FERDILLAIX] = speakTo(FLAG_TALKED_FERDILLAIX, "processEvent030", "followEvent030"),
		[FRAILOISE] = speakTo(FLAG_TALKED_FRAILOISE, "processEvent040", "followEvent040"),
		[ARNEGIS] = speakTo(FLAG_TALKED_ARNEGIS, "processEvent050", "followEvent050"),
	},
	[SEQ_001] = {
		[GINNADE] = function(player, quest)
			if offer(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
	always = {
		[GINNADE] = offer,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function seq000CheckCondition(data)
	return (data:GetFlag(FLAG_TALKED_ZONGGO) and
			data:GetFlag(FLAG_TALKED_WHAHTOA) and
			data:GetFlag(FLAG_TALKED_FERDILLAIX) and
			data:GetFlag(FLAG_TALKED_FRAILOISE) and
			data:GetFlag(FLAG_TALKED_ARNEGIS))
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if not data:GetFlag(FLAG_TALKED_ZONGGO) then table.insert(possibleMarkers, MRKR_ZONGGO) end
		if not data:GetFlag(FLAG_TALKED_WHAHTOA) then table.insert(possibleMarkers, MRKR_WHAHTOA) end
		if not data:GetFlag(FLAG_TALKED_FERDILLAIX) then table.insert(possibleMarkers, MRKR_FERDILLAIX) end
		if not data:GetFlag(FLAG_TALKED_FRAILOISE) then table.insert(possibleMarkers, MRKR_FRAILOISE) end
		if not data:GetFlag(FLAG_TALKED_ARNEGIS) then table.insert(possibleMarkers, MRKR_ARNEGIS) end
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_GINNADE)
	end

	return unpack(possibleMarkers)
end