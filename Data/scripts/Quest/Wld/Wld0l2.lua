require("Global")
require("Quest")

--[[
Letting Out Orion's Belt (Wld0l2, 110772). Prereq: Level 10 on any class. Rewards 200 gil.
--]]

local seq000CheckCondition

-- Sequence Numbers
local SEQ_000 = 0  -- Talk to the four gourmands.
local SEQ_001 = 1  -- Return to Ahldskyf.

-- Actor Class Ids
local AHLDSKYF		= 1000332
local FZHUMII			= 1000226
local SHOSHOMA		= 1000334
local DACA_JINJAHL 	= 1000202
local AENTFOET		= 1000064

-- Quest Markers
local MRKR_FZHUMII		= 11110101
local MRKR_SHOSHOMA		= 11110102
local MRKR_DACA_JINJAHL	= 11110103
local MRKR_AENTFOET		= 11110104
local MRKR_AHLDSKYF		= 11110105

-- Quest Flags
local FLAG_TALKED_FZHUMII	 		= 0
local FLAG_TALKED_SHOSHOMA 		= 1
local FLAG_TALKED_DACA_JINJAHL 	= 2
local FLAG_TALKED_AENTFOET 		= 3

-- Quest Counters
local COUNTER_TALKED          	= 0

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(AHLDSKYF, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		local data = quest:GetData()
		quest:SetENpc(AHLDSKYF)
		quest:SetENpc(FZHUMII,      (not data:GetFlag(FLAG_TALKED_FZHUMII) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(SHOSHOMA,     (not data:GetFlag(FLAG_TALKED_SHOSHOMA) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(DACA_JINJAHL, (not data:GetFlag(FLAG_TALKED_DACA_JINJAHL) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(AENTFOET,   	(not data:GetFlag(FLAG_TALKED_AENTFOET) and QFLAG_TALK or QFLAG_OFF))
	elseif sequence == SEQ_001 then
		quest:SetENpc(AHLDSKYF, QFLAG_REWARD)
	end
end

-- First talk plays the line and counts towards the four; later talks play the repeat line.
local function passOnWord(checkFlag, setFlag, firstEvent, repeatEvent)
	return function(player, quest)
		local data = quest:GetData()
		if data:GetFlag(checkFlag) then
			callClientFunction(player, "delegateEvent", player, quest, repeatEvent)
			return
		end
		callClientFunction(player, "delegateEvent", player, quest, firstEvent)
		data:SetFlag(setFlag)

		local counterAmount = data:IncCounter(COUNTER_TALKED)
		attentionMessage(player, 51063, 0, counterAmount, 4) -- ????. (... of 5)
		if seq000CheckCondition(data) then
			attentionMessage(player, 25225, quest:GetQuestId()) -- "Letting Out Orion's Belt" objectives complete!
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_001)
		end
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[AHLDSKYF] = function(player, quest)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAhldskyffStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	[SEQ_000] = {
		[AHLDSKYF] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventAhldskyffStart_1")
		end,
		[FZHUMII] = passOnWord(FLAG_TALKED_FZHUMII, FLAG_TALKED_FZHUMII, "processEvent000", "processEvent000_1"),
		[SHOSHOMA] = passOnWord(FLAG_TALKED_SHOSHOMA, FLAG_TALKED_SHOSHOMA, "processEvent005", "processEvent005_1"),
		[DACA_JINJAHL] = passOnWord(FLAG_TALKED_DACA_JINJAHL, FLAG_TALKED_KEKETO, "processEvent010", "processEvent010_1"),
		[AENTFOET] = passOnWord(FLAG_TALKED_AENTFOET, FLAG_TALKED_AENTFOET, "processEvent015", "processEvent015_1"),
	},
	[SEQ_001] = {
		[AHLDSKYF] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
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

-- Check if all souls are talked to
function seq000CheckCondition(data)
	return (data:GetFlag(FLAG_TALKED_FZHUMII) and
			data:GetFlag(FLAG_TALKED_SHOSHOMA) and
			data:GetFlag(FLAG_TALKED_DACA_JINJAHL) and
			data:GetFlag(FLAG_TALKED_AENTFOET))
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if not data:GetFlag(FLAG_TALKED_FZHUMII) then table.insert(possibleMarkers, MRKR_FZHUMII) end
		if not data:GetFlag(FLAG_TALKED_SHOSHOMA) then table.insert(possibleMarkers, MRKR_SHOSHOMA) end
		if not data:GetFlag(FLAG_TALKED_DACA_JINJAHL) then table.insert(possibleMarkers, MRKR_DACA_JINJAHL) end
		if not data:GetFlag(FLAG_TALKED_AENTFOET) then table.insert(possibleMarkers, MRKR_AENTFOET) end
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_AHLDSKYF)
	end

	return unpack(possibleMarkers)
end



