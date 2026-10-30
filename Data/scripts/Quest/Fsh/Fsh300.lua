require("Global")
require("Quest")
require("QuestFlow")

--[[
The Beast of the Barrel (Fsh300, 110501). Prereq: Fsh200; offered by N'nmulika at the Fishermen's
Guild. Counter 0 counts the emote rounds; counters 1-3 hold each Barrel species owned when the
rounds ended, so only a later catch counts. Walkthrough: Data/Docs/Scripts/Quest/Fsh/Fsh300.md.
--]]

local bounceTo

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
local SEQ_022 = 22
local SEQ_025 = 25
local SEQ_030 = 30
local SEQ_035 = 35
local SEQ_040 = 40
local SEQ_045 = 45

local NNMULIKA       = 1000153
local SISIPU         = 1000155
local RERENASU       = 1000201
local ROROJARU       = 1000374
local BARREL_TRIGGER = 1090008

local MRKR_SISIPU    = 11050101
local MRKR_RERENASU  = 11050102
local MRKR_BARREL_1  = 11050103
local MRKR_BARREL_2  = 11050104
local MRKR_ROROJARU  = 11050105
local MRKR_WAWALAGO  = 11050108
local MRKR_SISIPU2   = 11050109
local MRKR_SISIPU3   = 11050110
local MRKR_NNMULIKA  = 11050111
local MRKR_BARREL_3  = 11050112
local MRKR_BARREL_4  = 11050113

local KEYITEM_BARREL_FEED      = 11000025
local KEYITEM_WAWALAGO_MESSAGE = 11000133
local ITEM_STAR_SPANGLED_SUBLIGAR = 8050521

local TEXT_INVENTORY_FULL = 60022

local EMOTE_ROUNDS     = 4
local EMOTES_PER_ROUND = 4

-- The client script has no emote logic, so the rounds run here. Each Barrel point carries its
-- round's four emotes and any of the four answers it. Rows of this quest's text sheet: each
-- round's hint and success line.
local ROUND_TEXT = { { 119, 120 }, { 127, 128 }, { 135, 136 }, { 143, 144 } }

local CNTR_EMOTE_ROUNDS = 0

-- The three species the Barrel was fed with: { item, baseline counter }.
local BARREL_FISH = {
	{ 3011201, 1 },
	{ 3011205, 2 },
	{ 3011208, 3 },
}

local BARREL_POINTS = { "fsh300_barrel_trigger_a", "fsh300_barrel_trigger_b", "fsh300_barrel_trigger_c", "fsh300_barrel_trigger_d" }

-- Landing spots are the public spawns of the actors and points they serve.
local BARREL_SHORE  = { -819.000, 1.000, 864.000, 0.0 }
local RERENASU_DOCK = { -640.270, 1.000, 401.350, 2.270 }
local SISIPU_WHARF  = { -620.820, 4.250, 354.550, 1.110 }
local ROROJARU_STALL = { 28.930, 192.000, 109.690, 1.840 }

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }

-- The phase-table test runs with a stand-in player that has no inventory.
local function ownedCount(player, itemId)
	if player.GetItemPackage == nil then
		return 0
	end
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	local total = 0
	for quality = 1, 2 do
		local n = 0
		while n < 99 and bag:HasItem(itemId, n + 1, quality) do
			n = n + 1
		end
		total = total + n
	end
	return total
end


local function isFishCaught(player, quest)
	for _, fish in ipairs(BARREL_FISH) do
		if ownedCount(player, fish[1]) > getQuestCounter(quest, fish[2]) then
			return true
		end
	end
	return false
end

local function isRoundOpen(round)
	return function(player, quest, data) return data:GetCounter(CNTR_EMOTE_ROUNDS) == round end
end

local function barrelIndex(npc)
	local name = npcName(npc)
	for i, point in ipairs(BARREL_POINTS) do
		if point == name then
			return i
		end
	end
	return nil
end

local BARREL_PUSH = { BARREL_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }

local PHASES = {
	[SEQ_000] = {
		enpcs = { { SISIPU, QFLAG_TALK } },
		markers = { MRKR_SISIPU },
	},
	[SEQ_005] = {
		enpcs = { { RERENASU, QFLAG_TALK } },
		markers = { MRKR_RERENASU },
	},
	[SEQ_010] = {
		enpcs = { BARREL_PUSH },
		markers = { MRKR_BARREL_1, MRKR_BARREL_2 },
	},
	[SEQ_015] = {
		enpcs = { { ROROJARU, QFLAG_TALK } },
		markers = { MRKR_ROROJARU },
	},
	[SEQ_020] = {
		enpcs = { { RERENASU, QFLAG_TALK } },
		markers = { MRKR_RERENASU },
	},
	-- The rounds walk the Barrel points in order, one marker each.
	[SEQ_022] = {
		enpcs = { { BARREL_TRIGGER, QFLAG_PUSH, talk = false, push = true, emote = true, spawn = true } },
		markers = {
			{ MRKR_BARREL_1, when = isRoundOpen(0) },
			{ MRKR_BARREL_2, when = isRoundOpen(1) },
			{ MRKR_BARREL_3, when = isRoundOpen(2) },
			{ MRKR_BARREL_4, when = isRoundOpen(3) },
		},
	},
	[SEQ_025] = {
		enpcs = { BARREL_PUSH },
		markers = { MRKR_BARREL_1, MRKR_BARREL_2, MRKR_BARREL_3, MRKR_BARREL_4 },
	},
	[SEQ_030] = {
		enpcs = { { SISIPU, QFLAG_TALK } },
		markers = { MRKR_SISIPU2 },
	},
	[SEQ_035] = {
		enpcs = { { SISIPU, QFLAG_TALK } },
		markers = { MRKR_SISIPU3 },
	},
	[SEQ_040] = {
		enpcs = { { SISIPU, QFLAG_TALK } },
		markers = { MRKR_WAWALAGO },
	},
	[SEQ_045] = {
		enpcs = { { NNMULIKA, QFLAG_REWARD } },
		markers = { MRKR_NNMULIKA },
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

-- Abandon (and completion) takes back what the quest handed out.
function onFinish(player, quest)
	takeKeyItem(player, KEYITEM_BARREL_FEED)
	takeKeyItem(player, KEYITEM_WAWALAGO_MESSAGE)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(NNMULIKA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[NNMULIKA] = function(player, quest)
			if inPrivateArea(player) then
				return
			end
			local accepted = delegateEvent(player, quest, "processEventNnmulikaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[SISIPU] = function(player, quest)
			delegateEvent(player, quest, "processEvent010")
			giveKeyItem(player, KEYITEM_BARREL_FEED)
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[RERENASU] = function(player, quest)
			if delegateEvent(player, quest, "processEvent010_1001") == 1 then
				delegateEvent(player, quest, "processEvent020")
				player:EndEvent()
				takeKeyItem(player, KEYITEM_BARREL_FEED)
				quest:StartSequence(SEQ_010)
				bounceTo(player, BARREL_SHORE)
				return true
			end
		end,
	},
	[SEQ_015] = {
		[ROROJARU] = function(player, quest)
			if not hasKeyItem(player, KEYITEM_WAWALAGO_MESSAGE) then
				return
			end
			delegateEvent(player, quest, "processEvent040")
			player:EndEvent()
			-- A full bag keeps the message here; the trade runs again on the next talk.
			local bag = player:GetItemPackage(INVENTORY_NORMAL)
			if not bag:IsSpaceForAdd(ITEM_STAR_SPANGLED_SUBLIGAR, 1, 1) then
				player:SendGameMessage(GetWorldMaster(), TEXT_INVENTORY_FULL, MESSAGE_TYPE_SYSTEM_ERROR)
				return true
			end
			bag:AddItem(ITEM_STAR_SPANGLED_SUBLIGAR, 1, 1)
			takeKeyItem(player, KEYITEM_WAWALAGO_MESSAGE)
			quest:StartSequence(SEQ_020)
			local p = RERENASU_DOCK
			warpTo(player, 230, nil, 0, p[1], p[2], p[3], p[4])
			return true
		end,
	},
	[SEQ_020] = {
		[RERENASU] = function(player, quest)
			local answer = delegateEvent(player, quest, "processEvent010_1002")
			player:EndEvent()
			if answer == 1 then
				setQuestCounter(quest, CNTR_EMOTE_ROUNDS, 0)
				quest:StartSequence(SEQ_022)
				bounceTo(player, BARREL_SHORE)
			end
			return true
		end,
	},
	[SEQ_030] = {
		[SISIPU] = function(player, quest)
			delegateEvent(player, quest, "processEvent050")
			quest:StartSequence(SEQ_035)
		end,
	},
	[SEQ_035] = {
		[SISIPU] = function(player, quest)
			delegateEvent(player, quest, "processEvent060")
			quest:StartSequence(SEQ_040)
		end,
	},
	[SEQ_040] = {
		[SISIPU] = function(player, quest)
			if delegateEvent(player, quest, "processEvent070") == 1 then
				quest:StartSequence(SEQ_045)
			end
		end,
	},
	[SEQ_045] = {
		[NNMULIKA] = function(player, quest)
			turnInQuest(player, quest, "processEvent075", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function bounceTo(player, p)
	bouncePlayer(player, p[1], p[2], p[3], p[4])
end

-- One emote round answered: the last one fixes the catch baselines and opens the fishing.
local function answerRound(player, quest)
	local rounds = getQuestCounter(quest, CNTR_EMOTE_ROUNDS)
	if rounds + 1 < EMOTE_ROUNDS then
		setQuestCounter(quest, CNTR_EMOTE_ROUNDS, rounds + 1)
		return
	end
	local data = quest:GetData()
	data:SetCounter(CNTR_EMOTE_ROUNDS, EMOTE_ROUNDS)
	for _, fish in ipairs(BARREL_FISH) do
		data:SetCounter(fish[2], ownedCount(player, fish[1]))
	end
	quest:StartSequence(SEQ_025)
end

-- Any of the four Barrel points answers, so the handlers go by the point's name, not its class.
local push = {
	[SEQ_010] = {
		other = function(player, quest, npc, point)
			if point == nil then
				return
			end
			delegateEvent(player, quest, "processEvent025")
			delegateEvent(player, quest, "processEvent030")
			player:EndEvent()
			giveKeyItem(player, KEYITEM_WAWALAGO_MESSAGE)
			quest:StartSequence(SEQ_015)
			local p = ROROJARU_STALL
			warpTo(player, 175, nil, 0, p[1], p[2], p[3], p[4])
			return true
		end,
	},
	[SEQ_022] = {
		-- The open round's point gives its hint; the emote answers it (onEmote).
		other = function(player, quest, npc, point)
			if point == nil then
				return
			end
			local round = getQuestCounter(quest, CNTR_EMOTE_ROUNDS) + 1
			if point == round and ROUND_TEXT[round] ~= nil then
				player:SendGameMessage(quest, ROUND_TEXT[round][1], 0x20)
			end
		end,
	},
	[SEQ_025] = {
		other = function(player, quest, npc, point)
			if point ~= nil and isFishCaught(player, quest) then
				player:EndEvent()
				quest:StartSequence(SEQ_030)
				bounceTo(player, SISIPU_WHARF)
				return true
			end
		end,
	},
}

function onPush(player, quest, npc, eventName)
	if runQuestHandler(push, player, quest, npc, barrelIndex(npc)) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- A round answers only its own four slots (emoteDefault1-4, 5-8, ...), so a stray emote changes nothing.
function onEmote(player, quest, npc, eventName)
	local round = getQuestCounter(quest, CNTR_EMOTE_ROUNDS)
	if quest:GetSequence() == SEQ_022 and barrelIndex(npc) == round + 1 then
		local slot = tonumber(string.match(eventName or "", "^emoteDefault(%d+)$"))
		if slot ~= nil and math.floor((slot - 1) / EMOTES_PER_ROUND) == round then
			player:SendGameMessage(quest, ROUND_TEXT[round + 1][2], 0x20)
			answerRound(player, quest)
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Refreshes icons and markers on a catch. Talks and pushes still read the inventory,
-- so a missed call changes nothing.
function onItemGained(player, quest, itemId, quantity, quality)
	for _, watched in ipairs({ BARREL_FISH[1][1], BARREL_FISH[2][1], BARREL_FISH[3][1] }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_022 then
		return getQuestCounter(quest, CNTR_EMOTE_ROUNDS), 0, 0, 0, EMOTE_ROUNDS
	elseif sequence == SEQ_025 then
		return isFishCaught(player, quest) and 1 or 0, 0, 0, 0, 1
	end
	return 0, 0, 0, 0, 0
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
