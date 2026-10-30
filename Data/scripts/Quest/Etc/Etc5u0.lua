require("Global")
require("Quest")

--[[

Quest Script

Name:   Ring of Deceit
Code:   Etc5u0
Id:     110848
Prereq: Level 1 on any class.  Second MSQ completed. (110002 Man0l1 / 110006 Man0g1 / 110010 Man0u1)
Notes:  Unlocks Ul'dah Inn exit from the rear entrance.  Rewards 200 EXP

]]

-- Sequence Numbers
local SEQ_000 = 0  -- Talk to Judithe
local SEQ_001 = 1  -- Return to Otopa Pottopa

-- Actor Class Ids
local OTOPA_POTTOPA           = 1000864
local JUDITHE                 = 1001443

-- Quest Markers
local MRKR_JUDITHE            = 11092001
local MRKR_OTOPA_POTTOPA      = 11092002



function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end


function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(OTOPA_POTTOPA, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(OTOPA_POTTOPA)
		quest:SetENpc(JUDITHE, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(OTOPA_POTTOPA, QFLAG_REWARD)
		quest:SetENpc(JUDITHE)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[OTOPA_POTTOPA] = function(player, quest, npc)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventOTOPAPOTTOPAStart")

			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_000] = {
		[OTOPA_POTTOPA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1")
		end,
		[JUDITHE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			attentionMessage(player, 25225, 110848) -- <Quest name> objectives complete!
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[JUDITHE] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		end,
		[OTOPA_POTTOPA] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1) -- 200 exp rewarded
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end


function getJournalInformation(player, quest)
end


function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local possibleMarkers = {}

	if sequence == SEQ_000 then
		table.insert(possibleMarkers, MRKR_JUDITHE)
	elseif sequence == SEQ_001 then
		table.insert(possibleMarkers, MRKR_OTOPA_POTTOPA)
	end

	return unpack(possibleMarkers)
end
