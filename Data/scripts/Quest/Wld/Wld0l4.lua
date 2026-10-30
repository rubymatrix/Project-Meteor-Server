require("Global")
require("Quest")

--[[
Sniffing Out a Profit (Wld0l4, 110774). Prereq: Letting Out Orion's Belt; level 37, any class.
--]]

local SEQ_000	= 0  -- Talk to Ryssfloh.
local SEQ_001	= 1  -- Talk to Faine.

local AHLDSKYF 	= 1000332
local FAINE	 	= 1001608

local MRKR_FAINE		= 11110301
local MRKR_AHLDSKYF	= 11110302

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(AHLDSKYF, QFLAG_TALK)
	end

	if sequence == SEQ_000 then
		quest:SetENpc(AHLDSKYF)
		quest:SetENpc(FAINE, QFLAG_TALK)
	elseif sequence == SEQ_001 then
		quest:SetENpc(FAINE)
		quest:SetENpc(AHLDSKYF, QFLAG_REWARD)
	end
end

-- Ahldskyf's offer stands at every step until it is taken.
local function offerIfNew(player, quest)
	if not player:HasQuest(quest) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAhldskyffStart")
		if questAccepted == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return true
	end
end

local talk = {
	[SEQ_000] = {
		[AHLDSKYF] = function(player, quest)
			if offerIfNew(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000")
		end,
		[FAINE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005")
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_001] = {
		[AHLDSKYF] = function(player, quest)
			if offerIfNew(player, quest) then return true end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
		[FAINE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2")
			quest:StartSequence(SEQ_001)
		end,
	},
	always = {
		[AHLDSKYF] = offerIfNew,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc) then return end
	quest:UpdateENPCs()
	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_FAINE
	elseif sequence == SEQ_001 then
		return MRKR_AHLDSKYF
	end
end