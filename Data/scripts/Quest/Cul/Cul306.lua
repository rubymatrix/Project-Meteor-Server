require("Global")
require("Quest")
require("QuestFlow")

--[[

Quest Script

Name:   Something in the Soup
Code:   Cul306
Id:     110442
Prereq: Mystery of the Gastronome Gone Home (Cul300 - 110441)

Seq 65535: Offered by Prudentia (Limsa Lominsa).
Seq 5:  Prudentia's Echo, Charlys's lead, the 6-4 statue (push) and the bethel Echo (push).
Seq 10: Gerulf's meat, R'sushmo's spice and Frailoise's recipe.
Seq 15: Synthesize the Foulbelly Meatball.
Seq 20: Synthesize the Devilbelly Meatball.
Seq 25: Deliver the Devilbelly Meatball down the ramp (push).
Seq 30: The 6-4 chase (push) and Charlys's finale.

Three push spawns share one class (cul306_64_trigger, cul306_bethel_trigger, cul306_ramp_trigger); the
handlers tell them apart by name. The cook checks run on every specialist talk, since nothing reports
a synthesis to the quest. Each baseline counter holds how many of one meatball the player owned at the
offer. Spawns, gates and class fills: Data/sql/seed/seed_quest_cul306_01.sql.

--]]

local SEQ_005 = 5
local SEQ_010 = 10
local SEQ_015 = 15
local SEQ_020 = 20
local SEQ_025 = 25
local SEQ_030 = 30

local GERULF    = 1000063
local FRAILOISE = 1000065
local CHARLYS   = 1000138
local PRUDENTIA = 1000168
local RSUSHMO   = 1000170
local TRIGGER   = 1090008 -- the three push spawns above

local MRKR_PRUDENTIA  = 11044201
local MRKR_STATUE     = 11044203
local MRKR_PRUDENTIA2 = 11044204
local MRKR_CHARLYS    = 11044206
local MRKR_RAMP       = 11044207
local MRKR_SYNTHESIS  = 11044208
local MRKR_GERULF     = 11044209
local MRKR_RSUSHMO    = 11044210
local MRKR_FRAILOISE  = 11044211

local ITEM_DEVILBELLY_MEATBALL  = 11000071
local ITEM_DEVILSHROOM          = 11000072
local ITEM_FOULBELLY_MEATBALL   = 11000073
local ITEM_QUEER_SMELLING_MEAT  = 11000074
local ITEM_SWEET_SMELLING_SPICE = 11000075

local DEVILSHROOMS_NEEDED = 2

local FLAG_ECHOED    = 0
local FLAG_LED       = 1
local FLAG_AT_STATUE = 2
local FLAG_MEAT      = 3
local FLAG_SPICE     = 4
local FLAG_RECIPE    = 5
local FLAG_CHASED    = 6

local CNTR_FOULBELLY_BASELINE  = 0
local CNTR_DEVILBELLY_BASELINE = 1

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 4720, gil = 36000 }

-- A synthesis result is quality 1 or 2. The phase-table test runs with a stand-in player that has no
-- inventory.
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

local function grantItem(player, itemId, count)
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(itemId, count, 1)
	player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, itemId)
end


local function flagOn(index)
	return function(player, quest, data) return data:GetFlag(index) end
end

local function flagOff(index)
	return function(player, quest, data) return not data:GetFlag(index) end
end

local isEchoPending = flagOff(FLAG_ECHOED)
local isLeadDone    = flagOn(FLAG_LED)
local isStatueReached = flagOn(FLAG_AT_STATUE)
local isChased      = flagOn(FLAG_CHASED)
local isChasePending = flagOff(FLAG_CHASED)

local function isLeadPending(player, quest, data)
	return data:GetFlag(FLAG_ECHOED) and not data:GetFlag(FLAG_LED)
end

local function isStatuePending(player, quest, data)
	return data:GetFlag(FLAG_LED) and not data:GetFlag(FLAG_AT_STATUE)
end

local function isFoulbellyCooked(player, quest)
	return ownedCount(player, ITEM_FOULBELLY_MEATBALL) > getQuestCounter(quest, CNTR_FOULBELLY_BASELINE)
end

local function isDevilbellyCooked(player, quest)
	return ownedCount(player, ITEM_DEVILBELLY_MEATBALL) > getQuestCounter(quest, CNTR_DEVILBELLY_BASELINE)
end

local function countGrants(quest)
	local done = 0
	for _, flag in ipairs({ FLAG_MEAT, FLAG_SPICE, FLAG_RECIPE }) do
		if getQuestFlag(quest, flag) then
			done = done + 1
		end
	end
	return done
end

-- The specialists stay listed after their grants so lost materials can be fetched again.
local SPECIALISTS = {
	GERULF, RSUSHMO, FRAILOISE,
	{ TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
}

local PHASES = {
	[SEQ_005] = {
		enpcs = {
			{ PRUDENTIA, QFLAG_TALK, when = isEchoPending },
			{ CHARLYS, QFLAG_TALK, when = isLeadPending },
			{ TRIGGER, QFLAG_PUSH, when = isLeadDone, talk = false, push = isLeadDone, spawn = true },
		},
		markers = {
			{ MRKR_PRUDENTIA, when = isEchoPending },
			{ MRKR_CHARLYS, when = isLeadPending },
			{ MRKR_STATUE, when = isStatuePending },
			{ MRKR_PRUDENTIA2, when = isStatueReached },
		},
	},
	[SEQ_010] = {
		enpcs = {
			{ GERULF, QFLAG_TALK, when = flagOff(FLAG_MEAT) },
			{ RSUSHMO, QFLAG_TALK, when = flagOff(FLAG_SPICE) },
			{ FRAILOISE, QFLAG_TALK, when = flagOff(FLAG_RECIPE) },
			{ TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true },
		},
		markers = {
			{ MRKR_GERULF, when = flagOff(FLAG_MEAT) },
			{ MRKR_RSUSHMO, when = flagOff(FLAG_SPICE) },
			{ MRKR_FRAILOISE, when = flagOff(FLAG_RECIPE) },
		},
	},
	[SEQ_015] = { enpcs = SPECIALISTS, markers = { MRKR_SYNTHESIS } },
	[SEQ_020] = { enpcs = SPECIALISTS, markers = { MRKR_SYNTHESIS } },
	[SEQ_025] = { enpcs = SPECIALISTS, markers = { MRKR_RAMP } },
	[SEQ_030] = {
		enpcs = {
			{ CHARLYS, QFLAG_REWARD, when = isChased },
			{ TRIGGER, QFLAG_PUSH, when = isChasePending, talk = false, push = isChasePending, spawn = true },
		},
		markers = {
			{ MRKR_STATUE, when = isChasePending },
			{ MRKR_CHARLYS, when = isChased },
		},
	},
}

-- The grant never exceeds two and stops once the Devilbelly is made.
local function topUpDevilshrooms(player, quest)
	if isDevilbellyCooked(player, quest) then
		return
	end
	local missing = DEVILSHROOMS_NEEDED - ownedCount(player, ITEM_DEVILSHROOM)
	if missing > 0 then
		grantItem(player, ITEM_DEVILSHROOM, missing)
	end
end

-- Lost materials are made good only while no meatball cooked this run is held.
local function topUpMaterials(player, quest)
	if isFoulbellyCooked(player, quest) or isDevilbellyCooked(player, quest) then
		return
	end
	if getQuestFlag(quest, FLAG_MEAT) and ownedCount(player, ITEM_QUEER_SMELLING_MEAT) == 0 then
		grantItem(player, ITEM_QUEER_SMELLING_MEAT, 1)
	end
	if getQuestFlag(quest, FLAG_SPICE) and ownedCount(player, ITEM_SWEET_SMELLING_SPICE) == 0 then
		grantItem(player, ITEM_SWEET_SMELLING_SPICE, 1)
	end
end

local function advanceAfterGrants(quest)
	if countGrants(quest) >= 3 then
		quest:StartSequence(SEQ_015)
	end
end

-- Cooking the Devilbelly uses the Foulbelly up, so either one proves 15 done.
local function checkCooking(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_015 and (isFoulbellyCooked(player, quest) or isDevilbellyCooked(player, quest)) then
		quest:StartSequence(SEQ_020)
		sequence = SEQ_020
	end
	if sequence == SEQ_020 and isDevilbellyCooked(player, quest) then
		quest:StartSequence(SEQ_025)
	end
	topUpMaterials(player, quest)
end

-- Specialist: { scene, grant item, flag }. Frailoise's recipe has no scene in the client script, so it
-- is learned silently.
local SPECIALIST_GRANTS = {
	[GERULF]    = { "processEvent030", ITEM_QUEER_SMELLING_MEAT, FLAG_MEAT },
	[RSUSHMO]   = { "processEvent040", ITEM_SWEET_SMELLING_SPICE, FLAG_SPICE },
	[FRAILOISE] = { nil, nil, FLAG_RECIPE },
}

-- The challenge opens at once, so the meatballs held now are the baselines.
function onStart(player, quest)
	local data = quest:GetData()
	data:SetCounter(CNTR_FOULBELLY_BASELINE, ownedCount(player, ITEM_FOULBELLY_MEATBALL))
	data:SetCounter(CNTR_DEVILBELLY_BASELINE, ownedCount(player, ITEM_DEVILBELLY_MEATBALL))
	quest:StartSequence(SEQ_005)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(PRUDENTIA, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == PRUDENTIA then
			local accepted = delegateEvent(player, quest, "processEventPrudentiaStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif sequence == SEQ_005 then
		if classId == PRUDENTIA and not getQuestFlag(quest, FLAG_ECHOED) then
			if delegateEvent(player, quest, "processEvent020") == 1 then
				setQuestFlagOn(quest, FLAG_ECHOED)
			end
		elseif classId == CHARLYS and getQuestFlag(quest, FLAG_ECHOED) and not getQuestFlag(quest, FLAG_LED) then
			setQuestFlagOn(quest, FLAG_LED)
		end
	elseif sequence >= SEQ_010 and sequence <= SEQ_025 and SPECIALIST_GRANTS[classId] ~= nil then
		local grant = SPECIALIST_GRANTS[classId]
		if sequence == SEQ_010 and not getQuestFlag(quest, grant[3]) then
			if grant[1] ~= nil then
				delegateEvent(player, quest, grant[1])
				grantItem(player, grant[2], 1)
			end
			setQuestFlagOn(quest, grant[3])
			advanceAfterGrants(quest)
		else
			checkCooking(player, quest)
		end
	elseif sequence == SEQ_030 and classId == CHARLYS and getQuestFlag(quest, FLAG_CHASED) then
		turnInQuest(player, quest, "processEvent070", COMPLETION_REWARDS)
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc, eventName)
	local sequence = quest:GetSequence()
	local name = npcName(npc)

	if sequence == SEQ_005 and name == "cul306_64_trigger" then
		if getQuestFlag(quest, FLAG_LED) and not getQuestFlag(quest, FLAG_AT_STATUE) then
			setQuestFlagOn(quest, FLAG_AT_STATUE)
		end
	elseif sequence == SEQ_005 and name == "cul306_bethel_trigger" and getQuestFlag(quest, FLAG_AT_STATUE) then
		if delegateEvent(player, quest, "processEvent050") == 1 then
			topUpDevilshrooms(player, quest)
			quest:StartSequence(SEQ_010)
		end
	elseif sequence >= SEQ_010 and sequence <= SEQ_025 and name == "cul306_bethel_trigger" then
		topUpDevilshrooms(player, quest)
	elseif sequence == SEQ_025 and name == "cul306_ramp_trigger" and isDevilbellyCooked(player, quest) then
		delegateEvent(player, quest, "processEvent060")
		if isDevilbellyCooked(player, quest) then
			removeOne(player, ITEM_DEVILBELLY_MEATBALL)
			quest:StartSequence(SEQ_030)
		end
	elseif sequence == SEQ_030 and name == "cul306_64_trigger" and not getQuestFlag(quest, FLAG_CHASED) then
		delegateEvent(player, quest, "processEvent065")
		setQuestFlagOn(quest, FLAG_CHASED)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The journal counts live progress, never a stored copy.
-- A craft or a catch shows on the icons and markers at once (the server's inventory hook); the talks and
-- pushes still read the inventory, so a missed call changes nothing.
function onItemGained(player, quest, itemId, quantity, quality)
	for _, watched in ipairs({ ITEM_DEVILBELLY_MEATBALL, ITEM_DEVILSHROOM, ITEM_FOULBELLY_MEATBALL, ITEM_QUEER_SMELLING_MEAT, ITEM_SWEET_SMELLING_SPICE }) do
		if itemId == watched then
			quest:UpdateENPCs()
			return
		end
	end
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_005 then
		local done = 0
		for _, flag in ipairs({ FLAG_ECHOED, FLAG_LED, FLAG_AT_STATUE }) do
			done = done + (getQuestFlag(quest, flag) and 1 or 0)
		end
		return done, 0, 0, 0, 3
	elseif sequence == SEQ_010 then
		return countGrants(quest), 0, 0, 0, 3
	elseif sequence == SEQ_015 then
		return (isFoulbellyCooked(player, quest) or isDevilbellyCooked(player, quest)) and 1 or 0, 0, 0, 0, 1
	elseif sequence == SEQ_020 or sequence == SEQ_025 then
		return isDevilbellyCooked(player, quest) and 1 or 0, 0, 0, 0, 1
	elseif sequence == SEQ_030 then
		return getQuestFlag(quest, FLAG_CHASED) and 1 or 0, 0, 0, 0, 1
	end
	return 0, 0, 0, 0, 0
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
