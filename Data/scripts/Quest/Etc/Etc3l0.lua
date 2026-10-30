require("Global")
require("Quest")

local seq000CheckCondition

--[[

Quest Script

Name: 	The Tug of the Whorl 
Code: 	Etc3l0
Id: 	110653
Prereq: Level 5, Any Class

]]

-- Sequence Numbers
local SEQ_000	= 0  -- Talk to all the citizens.
local SEQ_001	= 1  -- Return to Ginnade.

-- Actor Class Ids
local GINNADE 		= 1000132
local ZONGGO			= 1000057
local WHAHTOA			= 1000475
local FERDILLAIX 		= 1000344
local FRAILOISE 		= 1000065
local ARNEGIS 		= 1000227

-- Quest Markers
local MRKR_ZONGGO			= 11070001
local MRKR_WHAHTOA		= 11070002
local MRKR_FERDILLAIX		= 11070003
local MRKR_FRAILOISE		= 11070004
local MRKR_ARNEGIS		= 11070005
local MRKR_GINNADE		= 11070006

-- Quest Flags
local FLAG_TALKED_ZONGGO 			= 0
local FLAG_TALKED_WHAHTOA 		= 1
local FLAG_TALKED_FERDILLAIX 		= 2
local FLAG_TALKED_FRAILOISE	 	= 3
local FLAG_TALKED_ARNEGIS 		= 4

-- Quest Counters
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

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc:GetActorClassId()
	local seq = quest:GetSequence()
	local incCounter = false

	-- Offer the quest
	if npcClassId == GINNADE and not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGinnadeStart")
		if questAccepted == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return
	end

	-- Quest Progress
	local data = quest:GetData()
	if seq == SEQ_000 then
		if npcClassId == GINNADE then
			callClientFunction(player, "delegateEvent", player, quest, "followEvent005")
		elseif npcClassId == ZONGGO then
			if not data:GetFlag(FLAG_TALKED_ZONGGO) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
				data:SetFlag(FLAG_TALKED_ZONGGO)
				incCounter = true
			else
				callClientFunction(player, "delegateEvent", player, quest, "followEvent010")
			end
		elseif npcClassId == WHAHTOA then
			if not data:GetFlag(FLAG_TALKED_WHAHTOA) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
				data:SetFlag(FLAG_TALKED_WHAHTOA)
			   incCounter = true
			else
				callClientFunction(player, "delegateEvent", player, quest, "followEvent020")
			end
		elseif npcClassId == FERDILLAIX then
			if not data:GetFlag(FLAG_TALKED_FERDILLAIX) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent030")
				data:SetFlag(FLAG_TALKED_FERDILLAIX)
				incCounter = true
			else
				callClientFunction(player, "delegateEvent", player, quest, "followEvent030")
			end
		elseif npcClassId == FRAILOISE then
			if not data:GetFlag(FLAG_TALKED_FRAILOISE) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent040")
				data:SetFlag(FLAG_TALKED_FRAILOISE)
				incCounter = true
			else
				callClientFunction(player, "delegateEvent", player, quest, "followEvent040")
			end
		elseif npcClassId == ARNEGIS then
			if not data:GetFlag(FLAG_TALKED_ARNEGIS) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent050")
				data:SetFlag(FLAG_TALKED_ARNEGIS)
				incCounter = true
			else
				callClientFunction(player, "delegateEvent", player, quest, "followEvent050")
			end
		end

		-- Increase objective counter & play relevant messages
		if incCounter == true then
			local counterAmount = data:IncCounter(COUNTER_TALKED)

			attentionMessage(player, 51060, 0, counterAmount, 5) -- You have spoken with a Barracuda informant. (... of 5)

			if seq000CheckCondition(data) then -- All informants spoken to
				attentionMessage(player, 25225, quest:GetQuestId()) -- "The Tug of the Whorl" objectives complete!
				quest:UpdateENPCs() -- Band-aid for a QFLAG_TALK issue
				quest:StartSequence(SEQ_001)
			end
		end

	elseif seq == SEQ_001 then
		--Quest Complete
		if npcClassId == GINNADE then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end
	end
	quest:UpdateENPCs()
	player:EndEvent()
end

-- Check if all informants are talked to
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