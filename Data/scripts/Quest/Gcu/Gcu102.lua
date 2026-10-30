require("Global")
require("Quest")
require("QuestDuty")

--[[
Like Father, Like Son (Gcu102, 111827). Prereq: Gcu101; level 40, Immortal Flames rank 11.
The surviving Garlean has no known class: the cave push stands in for him, asked right after the
win and again at the cave. No markers.
--]]

local startDuty

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3
local SEQ_004	= 4

local AUBREY					= 1500198
local RYDER					= 1001815
local CID						= 1001572
local CAVE_TRIGGER			= 1090362

local DUTY_ZONE				= 170	-- Central Thanalan
local DUTY_AREA				= "SimpleContentGcu10201"
local DUTY_DIRECTOR			= "Quest/QuestDirectorGcu10201"
local DUTY_ANCHOR				= {50.0, 205.33, -400.0, 0.0}		-- in the cave mouth, facing in
local CAVE_RETURN				= {50.0, 203.72, -412.0, 0.0}		-- outside the push circle

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(AUBREY, QFLAG_TALK)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	quest:SetENpc(AUBREY)
	-- isSpawned: these story actors exist only for players on these steps.
	local ryderTalk = (sequence == SEQ_000 or sequence == SEQ_003)
	quest:SetENpc(RYDER, ryderTalk and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence <= SEQ_003)
	if sequence == SEQ_001 or sequence == SEQ_002 then
		quest:SetENpc(CAVE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	quest:SetENpc(CID, sequence == SEQ_004 and QFLAG_REWARD or QFLAG_OFF, true, false, false, sequence == SEQ_004)
end

local function talk(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local function interrogate(player, quest)
	if talk(player, quest, "processEvent010") == 1 then
		talk(player, quest, "processEvent015")
		quest:StartSequence(SEQ_003)
	end
end

local function say(fn)
	return function(player, quest)
		talk(player, quest, fn)
	end
end

local talkBySequence = {
	[SEQ_ACCEPT] = {
		[AUBREY] = function(player, quest)
			if talk(player, quest, "processEventStart") == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_000] = {
		[RYDER] = function(player, quest)
			talk(player, quest, "processEvent005", 0)
			quest:StartSequence(SEQ_001)
		end,
	},
	[SEQ_002] = {
		[RYDER] = say("processEvent010_2"),
	},
	[SEQ_003] = {
		[RYDER] = function(player, quest)
			talk(player, quest, "processEvent020")
			quest:StartSequence(SEQ_004)
		end,
	},
	[SEQ_004] = {
		[CID] = function(player, quest)
			talk(player, quest, "processEvent025")
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[AUBREY] = say("processEvent000_2"),
		[RYDER] = say("processEvent015_2"),
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talkBySequence, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local pushBySequence = {
	[SEQ_001] = {
		[CAVE_TRIGGER] = function(player, quest)
			if talk(player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return true
			end
		end,
	},
	[SEQ_002] = {
		[CAVE_TRIGGER] = interrogate,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(pushBySequence, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcu10201 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_001 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		quest:StartSequence(SEQ_002)
		interrogate(player, quest)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, CAVE_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, CAVE_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	return (sequence == SEQ_001) and 1 or 0
end

function getJournalMapMarkerList(player, quest)
end
