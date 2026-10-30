require("Global")
require("Quest")

--[[
A Call to Arms (Etc3u0, 110695). Prereq: Level 5, Any Class.
--]]

local seq000CheckCondition

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to all the ___.
local SEQ_001	= 1  -- Return to Fruhybolg.

-- Actor Class Ids
local FRUHYBOLG 		= 1000964
local ZOENGTERBIN 	= 1000784
local LETTICE 		= 1000788
local THIMM 			= 1001439
local VANNES 			= 1001464
local JEGER			= 1000655

-- Quest Markers
local MRKR_FRUHYBOLG		= 11090001
local MRKR_ZOENGTERBIN	= 11090002
local MRKR_LETTICE		= 11090003
local MRKR_THIMM			= 11090004
local MRKR_VANNES			= 11090005
local MRKR_JEGER			= 11090006

-- Quest Flags
local FLAG_TALKED_VANNES 			= 1
local FLAG_TALKED_JEGER	 		= 2
local FLAG_TALKED_LETTICE		 	= 3
local FLAG_TALKED_ZOENGTERBIN		= 4
local FLAG_TALKED_THIMM	 		= 5

-- Quest Counters
local COUNTER_TALKED              = 0

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(FRUHYBOLG, QFLAG_TALK)
	end

	local data = quest:GetData()
	if sequence == SEQ_000 then
		quest:SetENpc(FRUHYBOLG)
		quest:SetENpc(VANNES,       (not data:GetFlag(FLAG_TALKED_VANNES) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(JEGER,   		(not data:GetFlag(FLAG_TALKED_JEGER) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(LETTICE,      (not data:GetFlag(FLAG_TALKED_LETTICE) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(ZOENGTERBIN,  (not data:GetFlag(FLAG_TALKED_ZOENGTERBIN) and QFLAG_TALK or QFLAG_OFF))
		quest:SetENpc(THIMM,        (not data:GetFlag(FLAG_TALKED_THIMM) and QFLAG_TALK or QFLAG_OFF))
	elseif sequence == SEQ_001 then
		quest:SetENpc(FRUHYBOLG, QFLAG_REWARD)
	end
end

-- First talk plays the line and counts towards the five; later talks play the repeat line.
local function passOnWord(flag, firstEvent, repeatEvent)
	return function(player, quest, npc, data)
		if data:GetFlag(flag) then
			callClientFunction(player, "delegateEvent", player, quest, repeatEvent)
			return
		end
		callClientFunction(player, "delegateEvent", player, quest, firstEvent)
		data:SetFlag(flag)

		local counterAmount = data:IncCounter(COUNTER_TALKED)
		attentionMessage(player, 51062, 0, counterAmount, 5) -- You have passed on word of the rite. (... of 5)
		if seq000CheckCondition(data) then
			attentionMessage(player, 25225, quest:GetQuestId()) -- "A Call to Arms" objectives complete!
			quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
			quest:StartSequence(SEQ_001)
		end
	end
end

local talk = {
	[SEQ_000] = {
		[FRUHYBOLG] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventOffersAfter")
		end,
		[VANNES] = passOnWord(FLAG_TALKED_VANNES, "processEvent005_V", "processEvent005_V_2"),
		[JEGER] = passOnWord(FLAG_TALKED_JEGER, "processEvent005_J", "processEvent005_J_2"),
		[LETTICE] = passOnWord(FLAG_TALKED_LETTICE, "processEvent005_L", "processEvent005_L_2"),
		[ZOENGTERBIN] = passOnWord(FLAG_TALKED_ZOENGTERBIN, "processEvent005_Z", "processEvent005_Z_2"),
		[THIMM] = passOnWord(FLAG_TALKED_THIMM, "processEvent005_T", "processEvent005_T_2"),
	},
	[SEQ_001] = {
		[FRUHYBOLG] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if npc:GetActorClassId() == FRUHYBOLG and not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFhruybolgStart")
		if questAccepted == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return
	end

	runQuestHandler(talk, player, quest, npc, quest:GetData())
	quest:UpdateENPCs()
	player:EndEvent()
end


-- Check if all people are talked to
function seq000CheckCondition(data)
	return (data:GetFlag(FLAG_TALKED_VANNES) and
			data:GetFlag(FLAG_TALKED_JEGER) and
			data:GetFlag(FLAG_TALKED_LETTICE) and
			data:GetFlag(FLAG_TALKED_ZOENGTERBIN) and
			data:GetFlag(FLAG_TALKED_THIMM))
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		if not data:GetFlag(FLAG_TALKED_VANNES) then table.insert(possibleMarkers, MRKR_VANNES) end
		if not data:GetFlag(FLAG_TALKED_JEGER) then table.insert(possibleMarkers, MRKR_JEGER) end
		if not data:GetFlag(FLAG_TALKED_LETTICE) then table.insert(possibleMarkers, MRKR_LETTICE) end
		if not data:GetFlag(FLAG_TALKED_ZOENGTERBIN) then table.insert(possibleMarkers, MRKR_ZOENGTERBIN) end
		if not data:GetFlag(FLAG_TALKED_THIMM) then table.insert(possibleMarkers, MRKR_THIMM) end
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_FRUHYBOLG)
	end

	return unpack(possibleMarkers)
end