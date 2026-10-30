require("Global")
require("Quest")

--[[
Hearing Confession (Wld0g2, 110763). Prereq: level 10, any class.
--]]

local seq000CheckCondition

-- Sequence Numbers
local SEQ_000 = 0  -- Talk to the four lost souls.
local SEQ_001 = 1  -- Return to Swaenhylt

-- Actor Class Ids
local SWAENHYLT	= 1001582
local FLAVIELLE   = 1001459
local KEKETO		= 1001346
local CEADDA		= 1000330
local THIMM		= 1001439

-- Quest Markers
local MRKR_FLAVIELLE			= 11120101
local MRKR_KEKETO				= 11120102
local MRKR_CEADDA				= 11120103
local MRKR_THIMM				= 11120104
local MRKR_SWAENHYLT			= 11120105

-- Quest Flags
local FLAG_TALKED_FLAVIELLE 	= 0
local FLAG_TALKED_KEKETO 		= 1
local FLAG_TALKED_CEADDA 		= 2
local FLAG_TALKED_THIMM	 	= 3

-- Quest Counters
local COUNTER_TALKED          = 0

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SWAENHYLT, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		local data = quest:GetData()
		quest:SetENpc(SWAENHYLT)
		quest:SetENpc(FLAVIELLE,    (not data:GetFlag(FLAG_TALKED_FLAVIELLE) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(KEKETO,   	(not data:GetFlag(FLAG_TALKED_KEKETO) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(CEADDA,       (not data:GetFlag(FLAG_TALKED_CEADDA) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(THIMM,       	(not data:GetFlag(FLAG_TALKED_THIMM) and QFLAG_TALK or QFLAG_OFF))
	elseif sequence == SEQ_001 then
		quest:SetENpc(SWAENHYLT, QFLAG_REWARD)
	end
end

local function hearConfession(player, quest, flag, firstEvent, repeatEvent)
	local data = quest:GetData()
	if data:GetFlag(flag) then
		callClientFunction(player, "delegateEvent", player, quest, repeatEvent)
		return
	end
	callClientFunction(player, "delegateEvent", player, quest, firstEvent)
	data:SetFlag(flag)

	local counterAmount = data:IncCounter(COUNTER_TALKED)
	attentionMessage(player, 51063, 0, counterAmount, 4) -- You have heard a lost soul's confession. (... of 5)
	if seq000CheckCondition(data) then
		attentionMessage(player, 25225, quest:GetQuestId()) -- "Hearing Confessions" objectives complete!
		quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
		quest:StartSequence(SEQ_001)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		other = function(player, quest)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSwaenhyltStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[SWAENHYLT] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end,
		[FLAVIELLE] = function(player, quest)
			hearConfession(player, quest, FLAG_TALKED_FLAVIELLE, "processEvent005", "processEvent005_2")
		end,
		[KEKETO] = function(player, quest)
			hearConfession(player, quest, FLAG_TALKED_KEKETO, "processEvent010", "processEvent010_2")
		end,
		[CEADDA] = function(player, quest)
			hearConfession(player, quest, FLAG_TALKED_CEADDA, "processEvent015", "processEvent015_2")
		end,
		[THIMM] = function(player, quest)
			hearConfession(player, quest, FLAG_TALKED_THIMM, "processEvent020", "processEvent020_2")
		end,
	},
	[SEQ_001] = {
		[SWAENHYLT] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000CheckCondition(data)
	return (data:GetFlag(FLAG_TALKED_FLAVIELLE) and
			data:GetFlag(FLAG_TALKED_KEKETO) and
			data:GetFlag(FLAG_TALKED_CEADDA) and
			data:GetFlag(FLAG_TALKED_THIMM))
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if not data:GetFlag(FLAG_TALKED_FLAVIELLE) then table.insert(possibleMarkers, MRKR_FLAVIELLE) end
		if not data:GetFlag(FLAG_TALKED_KEKETO) then table.insert(possibleMarkers, MRKR_KEKETO) end
		if not data:GetFlag(FLAG_TALKED_CEADDA) then table.insert(possibleMarkers, MRKR_CEADDA) end
		if not data:GetFlag(FLAG_TALKED_THIMM) then table.insert(possibleMarkers, MRKR_THIMM) end
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_SWAENHYLT)
	end

	return unpack(possibleMarkers)
end



