require("Global")
require("Quest")
require("QuestDuty")

--[[
Alive (Gcl102, 111427). Prereq: Gcl101; level 40, Maelstrom rank 11. All in Upper La Noscea.
Walkthrough: Data/Docs/Scripts/Quest/Gcl/Gcl102.md.
--]]

local SEQ_000 = 0
local SEQ_001 = 1
local SEQ_002 = 2
local SEQ_003 = 3

local GUINCUM			= 1500199
local RHIKI			= 1001810	-- the client names him Rashaht
local ROEHMANNSYN		= 1001813	-- the client names him Myrganmoen
local HIDDEN_SUNSET	= 1001814
local CID				= 1001572
local EBRELNAUX		= 1060011
local JIJINA			= 1001733
local EBOLAFF			= 1001731
local SAELBMOHT		= 1001732
local SUZARI			= 1001736
local PASS_TRIGGER	= 1090361

local MRKR_ROEHMANNSYN	= 11181101
local MRKR_HIDDEN			= 11181102
local MRKR_RHIKI			= 11181103
local MRKR_CID			= 11181104
local MRKR_EBRELNAUX		= 11181105
local MRKR_JIJINA			= 11181106
local MRKR_CAMP			= 11181107
local MRKR_PASS			= 11181108

local DUTY_ZONE		= 135	-- Upper La Noscea
local DUTY_AREA		= "SimpleContentGcl10201"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcl10201"
local DUTY_ANCHOR		= {-507.3, 71.13, -2429.3, -2.36}
local PASS_RETURN		= {-505.0, 71.95, -2427.0, -2.36}		-- outside the push circle
local CRASH_SITE		= {-800.0, 49.76, -2396.0, -2.2}

local CREW = { EBRELNAUX, JIJINA, EBOLAFF, SAELBMOHT, SUZARI }
local CREW_TALK = {
	[EBRELNAUX] = "processEventEbrelnaux", [JIJINA] = "processEventJijina", [EBOLAFF] = "processEventBolaff",
	[SAELBMOHT] = "processEventSaelbmoht", [SUZARI] = "processEventSorezari",
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(GUINCUM, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end

	quest:SetENpc(GUINCUM)
	-- isSpawned: these story actors exist only for players on this quest.
	local rhikiFlag = QFLAG_OFF
	if sequence == SEQ_000 then
		rhikiFlag = QFLAG_TALK
	elseif sequence == SEQ_003 then
		rhikiFlag = QFLAG_REWARD
	end
	quest:SetENpc(RHIKI, rhikiFlag, true, false, false, true)
	quest:SetENpc(ROEHMANNSYN, QFLAG_OFF, true, false, false, true)
	quest:SetENpc(HIDDEN_SUNSET, QFLAG_OFF, true, false, false, true)
	if sequence == SEQ_001 then
		quest:SetENpc(PASS_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end

	local atSite = sequence >= SEQ_002
	quest:SetENpc(CID, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF, true, false, false, atSite)
	for _, id in ipairs(CREW) do
		quest:SetENpc(id, QFLAG_OFF, true, false, false, atSite)
	end
end

local function delegate(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function say(fn, ...)
	local args = { ... }
	return function(player, quest)
		delegate(player, quest, fn, unpack(args))
	end
end

local function crewTalk(suffix)
	return function(player, quest, npc)
		delegate(player, quest, CREW_TALK[npc:GetActorClassId()] .. suffix)
	end
end

local talk = {
	[SEQ_000] = {
		[RHIKI] = function(player, quest)
			delegate(player, quest, "processEventRashaht", 0, 0)
			quest:StartSequence(SEQ_001)
		end,
		[ROEHMANNSYN] = say("processEventMyrganmoen"),
		[HIDDEN_SUNSET] = say("processEventHidden"),
	},
	[SEQ_002] = {
		[CID] = function(player, quest)
			delegate(player, quest, "processEventCid")
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[RHIKI] = function(player, quest)
			delegate(player, quest, "processEventClear", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then
				player:CompleteQuest(quest)
			end
			return true
		end,
		[ROEHMANNSYN] = say("processEventMyrganmoen3"),
		[HIDDEN_SUNSET] = say("processEventHidden3"),
	},
	always = {
		[GUINCUM] = say("processEventStartAfter"),
		[RHIKI] = say("processEventRashaht2"),
		[ROEHMANNSYN] = say("processEventMyrganmoen2"),
		[HIDDEN_SUNSET] = say("processEventHidden2"),
		[CID] = say("processEventCid_2"),
	},
}
for id in pairs(CREW_TALK) do
	talk[SEQ_002][id] = crewTalk("")
	talk.always[id] = crewTalk("_2")
end

function onTalk(player, quest, npc)
	if quest:GetSequence() == SEQ_ACCEPT then
		if npc:GetActorClassId() == GUINCUM and delegate(player, quest, "processEventStart") == 1 then
			player:EndEvent()
			player:AcceptQuest(quest)
			return
		end
		player:EndEvent()
		return
	end

	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	if quest:GetSequence() == SEQ_001 and npc:GetActorClassId() == PASS_TRIGGER then
		if delegate(player, quest, "contentsJoinAskInBasaClass") == 1 then
			startQuestDuty(player, quest, {
				zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
				anchor = DUTY_ANCHOR
			})
			return
		end
	end
	player:EndEvent()
end

-- Called by QuestDirectorGcl10201 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		-- The cutscene fades in after the warp to the crash site.
		delegate(player, quest, "processEventNQ")
		quest:StartSequence(SEQ_002)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, CRASH_SITE)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
	endQuestDuty(player, duty, DUTY_ZONE, PASS_RETURN)
end

function getJournalInformation(player, quest)
	return quest:GetSequence() == SEQ_001 and 1 or 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 or sequence == SEQ_003 then
		return MRKR_RHIKI, MRKR_ROEHMANNSYN, MRKR_HIDDEN
	elseif sequence == SEQ_001 then
		return MRKR_PASS
	elseif sequence == SEQ_002 then
		return MRKR_CID, MRKR_EBRELNAUX, MRKR_JIJINA
	end
end
