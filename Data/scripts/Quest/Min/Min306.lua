require("Global")
require("Quest")
require("QuestFlow")

--[[
Runaway Little Girl (Min306, 110462). Prereq: Min300; Miner level 36, offered by Linette.
All Nenekko spawns share one class and all triggers are class 1090008, so the handlers tell them
apart by uniqueId: those steps are keyed by sequence alone. Spawns and class fills:
Data/sql/seed/seed_quest_min306_01.sql.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_013 = 13
local SEQ_015 = 15
local SEQ_020 = 20

local LINETTE           = 1000861
local MOMODI            = 1000841
local NENEKKO           = 1000604
local OBJECTIVE_TRIGGER = 1090008

local SPAWN_SILDIH_VIEW    = "min306_sildih_view"
local SPAWN_NENEKKO_BORDER = "min306_nenekko_border"
local SPAWN_NENEKKO_DOCKS  = "min306_nenekko_docks"

local MRKR_MOMODI  = 11046201
local MRKR_SILDIH  = 11046203
local MRKR_BORDER  = 11046204
local MRKR_DOCKS   = 11046205
local MRKR_LINETTE = 11046207

local NPCLS_AMAJINA = 25
local COMMAND_MASTER_OF_ROCK = 29724

-- One flag per pit, each dug once; a stop opens once every earlier stop is dug.
local STOP_PITS = {
	{ { name = "min306_dig_s1a", flag = 0 }, { name = "min306_dig_s1b", flag = 1 } },
	{ { name = "min306_dig_s2a", flag = 2 }, { name = "min306_dig_s2b", flag = 3 } },
	{ { name = "min306_dig_s3a", flag = 4 }, { name = "min306_dig_s3b", flag = 5 } },
}

-- The client reward sheet has no class-quest rows.
local COMPLETION_REWARDS = { exp = 4720, gil = 36000, commands = { COMMAND_MASTER_OF_ROCK } }

local function trigger()
	return { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }
end

local PHASES = {
	[SEQ_000] = { enpcs = { { MOMODI, QFLAG_TALK } }, markers = { MRKR_MOMODI } },
	[SEQ_005] = { enpcs = { trigger() }, markers = { MRKR_SILDIH } },
	[SEQ_010] = { enpcs = { { NENEKKO, QFLAG_TALK, spawn = true } }, markers = { MRKR_BORDER } },
	-- The docks marker guides the escort; the stops have no markers of their own.
	[SEQ_013] = { enpcs = { trigger(), { NENEKKO, QFLAG_OFF, spawn = true } }, markers = { MRKR_DOCKS } },
	[SEQ_015] = { enpcs = { { NENEKKO, QFLAG_TALK, spawn = true } }, markers = { MRKR_DOCKS } },
	[SEQ_020] = { enpcs = { { LINETTE, QFLAG_REWARD } }, markers = { MRKR_LINETTE } },
}

local function findPit(name)
	for stop, pits in ipairs(STOP_PITS) do
		for _, pit in ipairs(pits) do
			if pit.name == name then
				return stop, pit
			end
		end
	end
	return nil, nil
end

local function isStopOpen(data, stop)
	for earlier = 1, stop - 1 do
		for _, pit in ipairs(STOP_PITS[earlier]) do
			if not data:GetFlag(pit.flag) then
				return false
			end
		end
	end
	return true
end

local function areAllPitsDug(data)
	return isStopOpen(data, #STOP_PITS + 1)
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LINETTE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[LINETTE] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventLinetteStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[MOMODI] = function(player, quest)
			delegateEvent(player, quest, "processEvent013")
			quest:StartSequence(SEQ_005)
			-- The guild linkpearl comes with the inquiry, since accepting the quest is not a step.
			player:AddNpcLs(NPCLS_AMAJINA)
		end,
	},
	[SEQ_010] = {
		other = function(player, quest, npc, name)
			if name == SPAWN_NENEKKO_BORDER then
				quest:StartSequence(SEQ_013)
			end
		end,
	},
	[SEQ_015] = {
		other = function(player, quest, npc, name)
			if name == SPAWN_NENEKKO_DOCKS then
				delegateEvent(player, quest, "processEvent035")
				callNpcLs(quest, NPCLS_AMAJINA)
			end
		end,
	},
	[SEQ_020] = {
		[LINETTE] = function(player, quest)
			turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc, npcName(npc)) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local push = {
	[SEQ_005] = {
		other = function(player, quest, npc, name)
			if name == SPAWN_SILDIH_VIEW then
				delegateEvent(player, quest, "processEvent020")
				quest:StartSequence(SEQ_010)
			end
		end,
	},
	[SEQ_013] = {
		other = function(player, quest, npc, name)
			local stop, pit = findPit(name)
			local data = quest:GetData()
			if pit ~= nil and isStopOpen(data, stop) then
				if not data:GetFlag(pit.flag) then
					setQuestFlagOn(quest, pit.flag)
				end
				if areAllPitsDug(data) then
					delegateEvent(player, quest, "processEvent030")
					quest:StartSequence(SEQ_015)
				end
			end
		end,
	},
}

function onPush(player, quest, npc)
	runQuestHandler(push, player, quest, npc, npcName(npc))
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The twins' call has no text row: the read only closes the glow.
function onNpcLS(player, quest, from, msgStep)
	if from == NPCLS_AMAJINA and quest:GetSequence() == SEQ_015 then
		quest:EndOfNpcLsMsgs()
		quest:StartSequenceForNpcLs(SEQ_020)
	end
	player:EndEvent()
	quest:UpdateENPCs()
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
