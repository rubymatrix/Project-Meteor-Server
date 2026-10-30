require("Global")
require("Quest")
require("QuestFlow")

--[[
Polishing the Mast (Fsh306, 110502). Prereq: Fsh300. Offered by N'nmulika at the Fishermen's Guild.
The fish assignment is rolled once and stored, so a reload never rerolls or extends it.
Walkthrough and counters: Data/Docs/Scripts/Quest/Fsh/Fsh306.md.
--]]

local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_028 = 28

local NNMULIKA       = 1000153
local SISIPU         = 1000155
local MAISIE         = 1000173
local STAIRS_TRIGGER = 1090008

local MRKR_STAIRS    = 11050201
local MRKR_NNMULIKA  = 11050202
local MRKR_SISIPU    = 11050204
local MRKR_SISIPU2   = 11050205
local MRKR_MAISIE    = 11050206
local MRKR_NNMULIKA2 = 11050207

local ASSIGNABLE_FISH = {
	3011213,
	3011203,
	3011209,
	3011217,
	3011225,
}

-- Three bells to bring the fish in.
local ASSIGNMENT_SECONDS = 3 * 175
local TICK_SECONDS       = 16
local SALE_GIL           = 1000

local FLAG_ASSIGNED      = 0
local FLAG_ECHO_SISIPU_1 = 1
local FLAG_ECHO_SISIPU_2 = 2
local FLAG_ECHO_MAISIE   = 3

local CNTR_ASSIGNED_FISH = 0
local CNTR_FISH_BASELINE = 1
local CNTR_ASSIGNED_AT   = 2

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

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

local function removeOne(player, itemId)
	local bag = player:GetItemPackage(INVENTORY_NORMAL)
	for quality = 1, 2 do
		if bag:HasItem(itemId, 1, quality) then
			bag:RemoveItem(itemId, 1, quality)
			return
		end
	end
end


local function nowTick()
	return math.floor(os.time() / TICK_SECONDS) % 65536
end

local function assignedFish(quest)
	return ASSIGNABLE_FISH[getQuestCounter(quest, CNTR_ASSIGNED_FISH)]
end

local function isAssignmentExpired(quest)
	local elapsed = (nowTick() - getQuestCounter(quest, CNTR_ASSIGNED_AT)) % 65536
	return elapsed * TICK_SECONDS >= ASSIGNMENT_SECONDS
end

-- Only a fish gained after the assignment counts.
local function isFishHeld(player, quest)
	local itemId = assignedFish(quest)
	return itemId ~= nil and ownedCount(player, itemId) > getQuestCounter(quest, CNTR_FISH_BASELINE)
end

local function isSaleReady(player, quest)
	return getQuestFlag(quest, FLAG_ASSIGNED) and not isAssignmentExpired(quest) and isFishHeld(player, quest)
end

local function isFirstSisipuEchoPending(player, quest, data)
	return not data:GetFlag(FLAG_ECHO_SISIPU_1)
end

local function isSecondSisipuEchoPending(player, quest, data)
	return data:GetFlag(FLAG_ECHO_SISIPU_1) and not data:GetFlag(FLAG_ECHO_SISIPU_2)
end

local function isMaisieEchoPending(player, quest, data)
	return data:GetFlag(FLAG_ECHO_SISIPU_2) and not data:GetFlag(FLAG_ECHO_MAISIE)
end

local PHASES = {
	[SEQ_000] = {
		enpcs = { { STAIRS_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_STAIRS },
	},
	[SEQ_005] = {
		enpcs = { { NNMULIKA, QFLAG_TALK } },
		markers = { MRKR_NNMULIKA },
	},
	[SEQ_020] = {
		enpcs = { { NNMULIKA, QFLAG_TALK } },
	},
	-- Only the NPC whose Echo is next is declared.
	[SEQ_025] = {
		enpcs = function(player, quest, data)
			return { { isMaisieEchoPending(player, quest, data) and MAISIE or SISIPU, QFLAG_TALK } };
		end,
		markers = {
			{ MRKR_SISIPU, when = isFirstSisipuEchoPending },
			{ MRKR_SISIPU2, when = isSecondSisipuEchoPending },
			{ MRKR_MAISIE, when = isMaisieEchoPending },
		},
	},
	[SEQ_028] = {
		enpcs = { { NNMULIKA, QFLAG_REWARD } },
		markers = { MRKR_NNMULIKA2 },
	},
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(NNMULIKA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local function nnmulikaSale(player, quest)
	if not getQuestFlag(quest, FLAG_ASSIGNED) then
		delegateEvent(player, quest, "processEvent015")
		local slot = math.random(#ASSIGNABLE_FISH)
		local data = quest:GetData()
		data:SetCounter(CNTR_ASSIGNED_FISH, slot)
		data:SetCounter(CNTR_FISH_BASELINE, ownedCount(player, ASSIGNABLE_FISH[slot]))
		data:SetCounter(CNTR_ASSIGNED_AT, nowTick())
		setQuestFlagOn(quest, FLAG_ASSIGNED)
	elseif isAssignmentExpired(quest) then
		delegateEvent(player, quest, "processEvent015_2")
		clearQuestFlag(quest, FLAG_ASSIGNED)
	elseif isSaleReady(player, quest) then
		delegateEvent(player, quest, "processEvent016")
		-- The scene takes time, so the sale is checked again against the clock.
		if isSaleReady(player, quest) then
			removeOne(player, assignedFish(quest))
			giveGil(player, SALE_GIL)
			quest:StartSequence(SEQ_020)
		end
	else
		delegateEvent(player, quest, "processEvent015_3")
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[NNMULIKA] = function(player, quest)
			if inPrivateArea(player) then return end
			local accepted = delegateEvent(player, quest, "processEventNnmulikaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_005] = {
		[NNMULIKA] = function(player, quest) nnmulikaSale(player, quest) end,
	},
	[SEQ_020] = {
		[NNMULIKA] = function(player, quest)
			delegateEvent(player, quest, "processEvent030")
			quest:StartSequence(SEQ_025)
		end,
	},
	[SEQ_025] = {
		-- Each Echo asks first, and only a yes counts.
		[SISIPU] = function(player, quest, npc, data)
			if inPrivateArea(player) then return end
			if isFirstSisipuEchoPending(player, quest, data) then
				if delegateEvent(player, quest, "processEvent040") == 1 then
					setQuestFlagOn(quest, FLAG_ECHO_SISIPU_1)
				end
			elseif isSecondSisipuEchoPending(player, quest, data) then
				if delegateEvent(player, quest, "processEvent050") == 1 then
					setQuestFlagOn(quest, FLAG_ECHO_SISIPU_2)
				end
			end
		end,
		[MAISIE] = function(player, quest, npc, data)
			if not isMaisieEchoPending(player, quest, data) then return end
			if delegateEvent(player, quest, "processEvent060") == 1 then
				setQuestFlagOn(quest, FLAG_ECHO_MAISIE)
				quest:StartSequence(SEQ_028)
			end
		end,
	},
	[SEQ_028] = {
		[NNMULIKA] = function(player, quest)
			turnInQuest(player, quest, "processEvent070", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc, quest:GetData()) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	if quest:GetSequence() == SEQ_000 and npcName(npc) == "fsh306_stairs_trigger" then
		delegateEvent(player, quest, "processEvent010")
		quest:StartSequence(SEQ_005)
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
	for _, watched in ipairs({ unpack(ASSIGNABLE_FISH) }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_005 and getQuestFlag(quest, FLAG_ASSIGNED) then
		return isFishHeld(player, quest) and 1 or 0, 0, 0, 0, 1
	elseif sequence == SEQ_025 then
		local seen = 0
		for _, flag in ipairs({ FLAG_ECHO_SISIPU_1, FLAG_ECHO_SISIPU_2, FLAG_ECHO_MAISIE }) do
			if getQuestFlag(quest, flag) then
				seen = seen + 1
			end
		end
		return seen, 0, 0, 0, 3
	end
	return 0, 0, 0, 0, 0
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
