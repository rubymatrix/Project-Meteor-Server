require("Global")
require("Quest")

--[[
Cutthroat Prices (Etc3u3, 110728). Prereq: Level 15, Any Class.
--]]

SEQ_000	= 0  -- Talk to Stangyth.
SEQ_001 = 1  -- Talk to Hasthwab.

local MOMODI			= 1000841
local STANGYTH		= 1500208
HASTHWAB		= 1001064

local MRKR_STANGYTH	= 11090301
MRKR_HATHWAB	= 11090302

AIRSHIP_PASS_ITEMID	= 11000209

function onStart(player, quest)
	player:SendGameMessage(GetWorldMaster(), 25117, 0x20, AIRSHIP_PASS_ITEMID) -- You obtain a Airship Pass (ULD-LMS).
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(MOMODI, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(STANGYTH, QFLAG_TALK)
		quest:SetENpc(MOMODI)
	elseif sequence == SEQ_001 then
		quest:SetENpc(HASTHWAB, QFLAG_REWARD)
		quest:SetENpc(STANGYTH)
	end
end

local talk = {
	[SEQ_000] = {
		[STANGYTH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[HASTHWAB] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[STANGYTH] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01")
		end,
	},
	always = {
		[MOMODI] = function(player, quest)
			if not player:HasQuest(quest) then
				-- The client names this function after another NPC.
				local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMIOUNNEStart")
				if questAccepted == 1 then
					player:AcceptQuest(quest)
				end
				player:EndEvent()
				return true
			end
			if quest:GetSequence() == SEQ_000 then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent_000")
			end
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalInformation(player, quest)
	return quest:GetSequence() == SEQ_000 and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_STANGYTH
	elseif sequence == SEQ_001 then
		return MRKR_HATHWAB
	end
end