--[[

questflow.lua: shared helpers for story quest scripts (the MSQ and class quests).

A quest script keeps Meteor's callback shape (onStart, onStateChange, onTalk, onPush, onEmote, onNotice,
onNpcLS, getJournalInformation, getJournalMapMarkerList) and uses these helpers for the parts every
quest repeats. Ported examples: quests/man/man0u0.lua, man0u1.lua, man1u0.lua, man2u0.lua. The test
QuestPhaseTableTests checks every script that requires this file.

Phase tables
------------
A quest declares, per sequence, the ENPCs it owns and the journal markers it shows:

    PHASES = {
        [SEQ_000] = {
            enpcs = {
                WARBURTON,                                           -- talk only, no icon
                { ASCILIA, QFLAG_TALK, when = isAsciliaMarked, push = canPushAscilia },
                { EXIT_TRIGGER, QFLAG_PUSH, when = areLessonsDone, talk = false, push = true },
                { crowd = SCENE_CROWD },                             -- a list of talk-only classes
            },
            markers = { MRKR_X, { MRKR_Y, when = isYMarked } },
        },
    };

    function onStateChange(player, quest, sequence) applyPhase(player, quest, PHASES, sequence); end
    function getJournalMapMarkerList(player, quest) return unpack(phaseMarkers(player, quest, PHASES)); end

An enpcs entry is a class id, { crowd = {...} }, or { classId, icon, when=, talk=, push=, emote=, spawn= }.
icon is a QFLAG_* wire value (QFLAG_TALK "!", QFLAG_REWARD turn-in, QFLAG_PUSH for push circles,
QFLAG_OFF none) shown only while `when` holds. talk defaults to true, push/emote/spawn to false.
when/talk/push/emote/spawn may be booleans or predicates fn(player, quest, data). `enpcs` and
`markers` may also be functions returning the list. spawn = true is for quest-gated story actors
(server_eventnpc_quest_gated).

NPC linkshell flows
-------------------
    NPCLS_FLOW = {
        from = 1, sender = MOMODI_DISPLAY_ID,
        packs = { [SEQ_015] = {301, 302, 303}, [SEQ_045] = {301, 302, 303} },
        advances = { [SEQ_015] = SEQ_045 },
        onFirstRead = function(player, quest, sequence) end,   -- optional
    };
    function onNpcLS(player, quest, from, msgStep) readNpcLs(player, quest, NPCLS_FLOW, from, msgStep); end

A pack is readable at the sequence that armed it and at the one its read advances to, so list it under
both. One message per read (msgStep); the advance runs on the read itself because the client sends
nothing after a linkpearl read.

]]

require("Global")
require("Quest")
require("Tutorial")

TEXT_KEY_ITEM_OBTAINED = 25117  -- worldMaster "You obtain <item>."
TEXT_BOUND_BY_DUTY     = 50011
TEXT_UNBOUND_FROM_DUTY = 50012
TEXT_PROTECT_FROM_HARM = 51005
ITEM_GIL               = 1000001
MOD_MINIMUM_HP_LOCK    = 114    -- Modifier.MinimumHpLock
SIMPLE_CONTENT_CLASS   = "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent"

local function resolve(value, default, player, quest, data)
	if value == nil then
		return default
	end
	if type(value) == "function" then
		return value(player, quest, data) and true or false
	end
	return value
end

local function listOf(value, player, quest, data)
	if type(value) == "function" then
		return value(player, quest, data) or {}
	end
	return value or {}
end

local function setPhaseEnpc(player, quest, data, entry)
	if type(entry) == "number" then
		quest:SetENpc(entry)
		return
	end
	if entry.crowd ~= nil then
		for _, classId in ipairs(entry.crowd) do
			quest:SetENpc(classId)
		end
		return
	end
	local icon = entry[2] or QFLAG_OFF
	if not resolve(entry.when, true, player, quest, data) then
		icon = QFLAG_OFF
	end
	quest:SetENpc(entry[1], icon,
		resolve(entry.talk, true, player, quest, data),
		resolve(entry.push, false, player, quest, data),
		resolve(entry.emote, false, player, quest, data),
		resolve(entry.spawn, false, player, quest, data))
end

-- Sets the sequence's ENPCs from the phase table (call from onStateChange).
function applyPhase(player, quest, phases, sequence)
	local phase = phases[sequence]
	if phase == nil then
		return
	end
	local data = quest:GetData()
	for _, entry in ipairs(listOf(phase.enpcs, player, quest, data)) do
		setPhaseEnpc(player, quest, data, entry)
	end
end

-- The journal markers of the current sequence (getJournalMapMarkerList: return unpack(...)).
function phaseMarkers(player, quest, phases)
	local phase = phases[quest:GetSequence()]
	local markers = {}
	if phase == nil then
		return markers
	end
	local data = quest:GetData()
	for _, entry in ipairs(listOf(phase.markers, player, quest, data)) do
		if type(entry) == "number" then
			markers[#markers + 1] = entry
		elseif resolve(entry.when, true, player, quest, data) then
			markers[#markers + 1] = entry[1]
		end
	end
	return markers
end

-- Helpers call each other through these locals, so a quest that defines a global of the same name
-- (several older scripts have their own warpTo) cannot break them.
local function delegate(player, actor, eventName, ...)
	return callClientFunction(player, "delegateEvent", player, actor, eventName, ...)
end

local function zoneChange(player, zoneId, privateAreaName, privateAreaLevel, x, y, z, rot)
	GetWorldManager():DoZoneChange(player, zoneId, privateAreaName, privateAreaLevel or 0, 15, x, y, z, rot)
end

local function zoneIdOf(player)
	return player.CurrentArea.ZoneId
end

-- Plays a quest-actor event on the client and waits for it to finish. Returns the client's result.
function delegateEvent(player, actor, eventName, ...)
	return delegate(player, actor, eventName, ...)
end

-- Lines that answer in place and never move the journal: chatter[sequence][classId] = eventName.
-- Returns true when the NPC had a line.
function delegateChatter(player, quest, chatter, sequence, classId)
	local lines = chatter[sequence]
	local eventName = lines and lines[classId]
	if eventName == nil then
		return false
	end
	delegate(player, quest, eventName)
	return true
end

-- One linkpearl message per read (see the header).
function readNpcLs(player, quest, flow, from, msgStep)
	local sequence = quest:GetSequence()
	if from ~= flow.from then
		player:EndEvent()
		return
	end
	local pack = flow.packs[sequence]
	if type(pack) == "function" then
		pack = pack(player, quest, sequence)
	end
	if pack == nil or #pack == 0 then
		player:EndEvent()
		return
	end

	local step = math.max(1, math.min(msgStep, #pack))
	player:SendGameMessageLocalizedDisplayName(quest, pack[step], MESSAGE_TYPE_NPC_LINKSHELL, flow.sender)
	if step >= #pack then
		quest:EndOfNpcLsMsgs()
	else
		quest:ReadNpcLsMsg()
	end

	if step == 1 and flow.onFirstRead ~= nil then
		flow.onFirstRead(player, quest, sequence)
	end
	local advance = flow.advances and flow.advances[sequence]
	if advance ~= nil then
		quest:StartSequenceForNpcLs(advance)
	end
	player:EndEvent()
end

-- Lights the quest's linkpearl unless a call is already pending.
function callNpcLs(quest, from)
	if quest:GetData():GetNpcLsFrom() == 0 then
		quest:NewNpcLsMsg(from)
	end
end

-- Quest data that survives a crash: SetFlag/SetCounter alone are only written at logout.
function getQuestFlag(quest, index)
	return quest:GetData():GetFlag(index)
end

function setQuestFlagOn(quest, index)
	local data = quest:GetData()
	data:SetFlag(index)
	data:Save()
end

function clearQuestFlag(quest, index)
	local data = quest:GetData()
	data:ClearFlag(index)
	data:Save()
end

function getQuestCounter(quest, index)
	return quest:GetData():GetCounter(index)
end

function setQuestCounter(quest, index, value)
	local data = quest:GetData()
	data:SetCounter(index, value)
	data:Save()
end

-- Location
function currentZoneId(player)
	return zoneIdOf(player)
end

function inPrivateArea(player)
	return player.CurrentArea:IsPrivate()
end

-- True in the given private area (name, level) of the given zone; level nil matches any level.
function inPrivateAreaOf(player, zoneId, name, level)
	local area = player.CurrentArea
	return area.ZoneId == zoneId and area:IsPrivate() and area:GetPrivateAreaName() == name
		and (level == nil or area:GetPrivateAreaType() == level)
end

-- The spawn's uniqueId, lowercase (several story spawns share a class and differ by name).
function npcName(npc)
	return string.lower(npc:GetUniqueId() or "")
end

-- Warps. Spawn type 15 lets the client resolve an event that ends with a fade-in after warp.
function warpTo(player, zoneId, privateAreaName, privateAreaLevel, x, y, z, rot)
	zoneChange(player, zoneId, privateAreaName, privateAreaLevel, x, y, z, rot)
end

function warpToPrivateArea(player, privateAreaLevel, x, y, z, rot, privateAreaName)
	zoneChange(player, zoneIdOf(player), privateAreaName or "PrivateAreaMasterPast", privateAreaLevel, x, y, z, rot)
end

function warpToPublic(player, x, y, z, rot)
	if x == nil then
		x, y, z, rot = player.positionX, player.positionY, player.positionZ, player.rotation
	end
	zoneChange(player, zoneIdOf(player), nil, 0, x, y, z, rot)
end

-- Re-zones where the player stands (public area of the zone): resolves a scene's after-warp fade.
function reloadInPlace(player, zoneId)
	zoneChange(player, zoneId or zoneIdOf(player), nil, 0, player.positionX, player.positionY, player.positionZ, player.rotation)
end

-- Moves the player inside the area. Default spawn type: 0x11 during an event leaves the client
-- waiting at the warp settle gate.
function bouncePlayer(player, x, y, z, rot)
	GetWorldManager():DoPlayerMoveInZone(player, x, y, z, rot)
end

-- The shared after-warp notice: the next zone-in plays the held quest's onNotice
-- (directors/AfterQuestWarpDirector.lua; the quest sets AFTER_WARP_NOTICE = true). A warp into another
-- zone must pass that zone's id, since a login director only binds in its own zone.
function kickAfterWarpNotice(player, zoneId)
	local director = GetWorldManager():GetArea(zoneId or zoneIdOf(player)):CreateDirector("AfterQuestWarpDirector", false)
	player:AddDirector(director)
	director:StartDirector(true)
	player:SetLoginDirector(director)
	player:KickEvent(director, "noticeEvent", true)
end

-- Lifts a director notice's Now Loading veil; the client also drops its staged notice target.
function dismissNowLoadingVeil(player, questActor)
	return delegate(player, questActor, "questBaseRewardSeting")
end

-- Items and gil
local function holdsKeyItem(player, itemId)
	return player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(itemId)
end

function hasKeyItem(player, itemId)
	return holdsKeyItem(player, itemId)
end

function giveKeyItem(player, itemId)
	if not holdsKeyItem(player, itemId) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(itemId, 1, 1)
		player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, itemId)
	end
end

function takeKeyItem(player, itemId)
	if holdsKeyItem(player, itemId) then
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(itemId, 1)
	end
end

function giveGil(player, amount)
	player:GetItemPackage(INVENTORY_CURRENCY):AddItem(ITEM_GIL, amount, 1)
end

-- Completion pay for a quest the client reward sheet has no row for (most class quests): EXP to the current
-- class, gil, items and command unlocks, each with its own log line. There is no reward window to show.
-- rewards = { exp = n, gil = n, items = { { itemId, qty }, ... }, commands = { commandId, ... } }
-- Declare it as the global COMPLETION_REWARDS: the server replays its commands at login.
local function rewardItems(rewards)
	local items = {}
	if (rewards.gil or 0) > 0 then
		items[#items + 1] = { ITEM_GIL, rewards.gil }
	end
	for _, item in ipairs(rewards.items or {}) do
		if type(item) == "number" then
			items[#items + 1] = { item, 1 }
		else
			items[#items + 1] = { item[1], item[2] or 1 }
		end
	end
	return items
end

local function payScriptRewards(player, rewards)
	if (rewards.exp or 0) > 0 then
		player:DoBattleAction(0, 0, player:AddExp(rewards.exp, player:GetCurrentClassOrJob(), 0))
	end
	for _, item in ipairs(rewardItems(rewards)) do
		player:GiveRewardItem(item[1], item[2])
	end
	for _, commandId in ipairs(rewards.commands or {}) do
		player:GrantCommandUnlock(commandId, true)
	end
end

-- Turn-in: the closing scene, the reward window (completion rewards come from the client reward sheet),
-- then completion. A full inventory leaves the quest open so the player can make room and try again.
-- A rewards table as the first extra argument is the pay for quests the sheet has no row for (see
-- payScriptRewards); it is ignored when the sheet has one. Any further arguments go to the scene.
--     turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
function turnInQuest(player, quest, eventName, ...)
	local args = { ... }
	local rewards = nil
	if type(args[1]) == "table" then
		rewards = table.remove(args, 1)
	end
	if rewards ~= nil and player:HasQuestRewardSheetRow(quest:GetQuestId()) then
		rewards = nil
	end
	if rewards ~= nil and not player:HasRoomForItems(rewardItems(rewards)) then
		-- Your inventory is full.
		player:SendGameMessage(GetWorldMaster(), 60022, MESSAGE_TYPE_SYSTEM_ERROR)
		player:EndEvent()
		return false
	end
	if eventName ~= nil then
		delegate(player, quest, eventName, unpack(args))
	end
	local rewarded = rewards ~= nil or showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then
		if rewards ~= nil then
			payScriptRewards(player, rewards)
		end
		player:CompleteQuest(quest)
	end
	return rewarded
end

-- Parley
--[[
A quest that needs a Parley won declares the board and two callbacks; nothing else:

    PARLEY = { row = 3001, displayNameId = THICKSET_TAILOR_DISPLAY_ID, topics = { 1036, 1034, ... } };
    function canParley(player, quest, npc)          -- is a Parley open on this npc now?
        return quest:GetSequence() == SEQ_015 and npc:GetActorClassId() == THICKSET_TAILOR;
    end                                             -- (or return a board table to override PARLEY)
    function onParleyEnd(player, quest, npc, outcome)   -- "won", "lost" or "abandoned"
        if (outcome == "won") then setQuestFlagOn(quest, FLAG_PARLEY_WON); end
    end

The Parley command (commands/NegotiationCommand.lua) hands the target to the held quest that owns it, which
runs onParley below. The quest's setup scene ("target X and choose Parley") calls parleyAfterSetup.
row is the client's negotiationTable row; the client shows the Parley entry only for an npc whose class
has property bits 0 and 3 (propertyFlags | 9). The board itself is not built yet: until it is, a Parley
started either way counts as won (PARLEY_BOARD_READY).
]]
TEXT_PARLEY_SUCCEEDED   = 40405
TEXT_PARLEY_FAILED      = 40406
TEXT_UNABLE_TO_PARLEY   = 40428
local PARLEY_BOARD_READY = false

local function parleyBoard(player, quest, npc)
	if canParley == nil then
		return nil
	end
	local open = canParley(player, quest, npc)
	if not open then
		return nil
	end
	return type(open) == "table" and open or (PARLEY or {})
end

local function endParley(player, quest, npc, outcome)
	if outcome == "won" then
		player:SendGameMessage(GetWorldMaster(), TEXT_PARLEY_SUCCEEDED, 0x20)
	elseif outcome == "lost" then
		player:SendGameMessage(GetWorldMaster(), TEXT_PARLEY_FAILED, 0x20)
	end
	if onParleyEnd ~= nil then
		onParleyEnd(player, quest, npc, outcome)
	end
	quest:UpdateENPCs()
end

-- The board on the client (NegotiationJudge widgets). Not built: every Parley is won.
local function playParleyBoard(player, quest, npc, board)
	return "won"
end

-- Called by the Parley command with its event open.
function onParley(player, quest, npc)
	local board = parleyBoard(player, quest, npc)
	if board == nil then
		player:SendGameMessage(GetWorldMaster(), TEXT_UNABLE_TO_PARLEY, 0x20, 0, 0, npc)
		player:EndEvent()
		return
	end
	local outcome = playParleyBoard(player, quest, npc, board)
	player:EndEvent()
	endParley(player, quest, npc, outcome)
end

-- After the quest's setup scene. Until the board exists the Parley it points at counts as won, so a
-- player without the Parley command (or without the board) is never stuck. Returns true when it settled it.
function parleyAfterSetup(player, quest, npc)
	if PARLEY_BOARD_READY or parleyBoard(player, quest, npc) == nil then
		return false
	end
	endParley(player, quest, npc, "won")
	return true
end

-- Opening-chain handoff: completes this quest and gives the next; the next quest's onStart plays its
-- opening scene on its own actor and warps. Call it with the triggering event still open: the next
-- quest's scene runs inside it, and its onStart ends it.
function beginNextQuest(player, quest, nextQuestName)
	player:ReplaceQuest(quest, nextQuestName)
end

-- Per-player signals (sendSignal wakes every waiter of that name, whoever it belongs to).
local function signalName(player, name)
	return name .. player.Id
end

function playerSignal(player, name)
	return signalName(player, name)
end

function sendPlayerSignal(player, name)
	sendSignal(signalName(player, name))
end

function waitForPlayerSignal(player, name, timeoutSeconds)
	return waitForSignal(signalName(player, name), timeoutSeconds)
end

-- Duty content
--[[
startQuestContent(player, def) creates a SimpleContent area, binds its director and zones the player in.
    def.zone      parent zone id (default: the zone the player is in)
    def.content   content script name, content/<content>.lua, also the area name
    def.director  director script under directors/ (its init() names the client director class)
    def.x, y, z, rot   arrival point
    def.spawnType 15 by default; 16 only when the director's notice plays a cutscene that drops the
                  client's Now Loading screen
Call with the asking event still open; it ends the event. Returns the area and its director (nil when
the area could not be made).
]]
function startQuestContent(player, def)
	local zone = GetWorldManager():GetZone(def.zone or zoneIdOf(player))
	local area = zone and zone:CreateContentArea(player, SIMPLE_CONTENT_CLASS, string.lower(def.content), def.content, def.director)
	if area == nil then
		player:EndEvent()
		return nil
	end

	local director = area:GetContentDirector()
	player:AddDirector(director)
	director:StartDirector(false)
	player:SetLoginDirector(director)
	player:EndEvent()
	-- The kick must ride the warp flush: delivered earlier, the client's notice record is corrupted.
	player:KickEvent(director, "noticeEvent", true)
	GetWorldManager():DoZoneChangeContent(player, area, def.x, def.y, def.z, def.rot or 0, def.spawnType or 15)
	return area, director
end

-- Waits (up to ~10 s) for the player's zone-in to the named content area; nil if it never happened.
function waitForContentArea(player, contentName)
	for i = 1, 20 do
		local area = player.CurrentArea
		if area ~= nil and area:GetPrivateAreaName() == contentName then
			return area
		end
		wait(0.5)
	end
	return nil
end

--[[
Runs a director's quest fight: waits for the player's zone-in, starts the fight's content
(Content/Quest/<encounter>.lua) and hands the outcome to the quest. Nothing happens if the player
left or the quest moved on. fight = { quest, content, encounter, sequence, win, fail, reviveOnFail };
win and fail get (player, quest, encounter, area).
--]]
function runQuestFight(player, director, fight)
	player:EndEvent()
	if player:GetQuest(fight.quest) == nil then
		return
	end
	local area = waitForContentArea(player, fight.content)
	if area == nil then
		return
	end
	local encounter = StartContent(fight.encounter, "", area, player, { director = director })
	if encounter == nil then
		return
	end
	while encounter.IsRunning and player.CurrentArea == area do
		wait(1)
	end

	local quest = player:GetQuest(fight.quest)
	if player.CurrentArea ~= area or quest == nil or quest:GetSequence() ~= fight.sequence then
		encounter:Close()
		return
	end
	if encounter.Result == "win" then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		fight.win(player, quest, encounter, area)
	else
		if fight.reviveOnFail then
			wait(3)
			if player:IsDead() then
				player:Revive(100)
			end
		end
		fight.fail(player, quest, encounter, area)
	end
end

-- Leaves duty content: unbind message, the fight's actors removed, the area released, the warp out.
-- dest = { zone, privateAreaName, privateAreaLevel, x, y, z, rot } (privateAreaName nil = public).
function leaveQuestContent(player, fight, area, dest)
	player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
	player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
	player:EndEvent()
	if fight ~= nil then
		fight:Close()
	end
	if area ~= nil then
		pcall(function() area:ContentFinished() end)
	end
	if dest ~= nil then
		zoneChange(player, dest.zone, dest.privateAreaName, dest.privateAreaLevel, dest.x, dest.y, dest.z, dest.rot)
	end
end
