require("Global")
require("Quest")
require("QuestFlow")

--[[
Runaway Little Girl (Min306, quest 110462). Follows Min300, Miner level 36. Offered by Linette
(processEventLinetteStart, accepted on 1).

Seq 0:   Momodi's inquiry at the Quicksand (processEvent013; the Amajina & Sons linkpearl).
Seq 5:   The mirage viewpoint in Central Thanalan (push, processEvent020).
Seq 10:  Nenekko at the western Thanalan border (talk, no scene).
Seq 13:  The escort west: a pair of digs at each of three stops, in stop order. The last dig plays the
         docks scene (processEvent030).
Seq 15:  Nenekko's farewell at the Vesper Bay docks (processEvent035) lights the twins' linkpearl; the
         read (no text row) closes the glow and moves to 20.
Seq 20:  Linette's reward.

All Nenekko spawns share one class (border, three stops, docks) and all triggers are class 1090008; the
handlers tell them apart by uniqueId. Completion: processEvent040, then COMPLETION_REWARDS
(with the Master of Rock command).
Spawns and class fills: Data/sql/seed/seed_quest_min306_01.sql.
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

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local name = npcName(npc)

	if sequence == SEQ_ACCEPT and classId == LINETTE then
		local accepted = delegateEvent(player, quest, "processEventLinetteStart")
		player:EndEvent()
		if accepted == 1 then
			player:AcceptQuest(quest)
		end
		return
	elseif sequence == SEQ_000 and classId == MOMODI then
		delegateEvent(player, quest, "processEvent013")
		quest:StartSequence(SEQ_005)
		-- The guild linkpearl comes with the inquiry, since accepting the quest is not a step.
		player:AddNpcLs(NPCLS_AMAJINA)
	elseif sequence == SEQ_010 and name == SPAWN_NENEKKO_BORDER then
		quest:StartSequence(SEQ_013)
	elseif sequence == SEQ_015 and name == SPAWN_NENEKKO_DOCKS then
		delegateEvent(player, quest, "processEvent035")
		callNpcLs(quest, NPCLS_AMAJINA)
	elseif sequence == SEQ_020 and classId == LINETTE then
		turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local name = npcName(npc)

	if sequence == SEQ_005 and name == SPAWN_SILDIH_VIEW then
		delegateEvent(player, quest, "processEvent020")
		quest:StartSequence(SEQ_010)
	elseif sequence == SEQ_013 then
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
	end

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
