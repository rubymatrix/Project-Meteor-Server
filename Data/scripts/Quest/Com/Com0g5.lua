require("Global")
require("Quest")
require("QuestDuty")

--[[
Their Finest Hour (Com0g5, 111605). Prereq: Com0g4; level 25.
Not wired yet: the Earthbreaker from the menu, the amphitheatre crowd and Fulke's hint.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0g5.md.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3

local FULKE					= 1500200
local PAPALYMO				= 1002070	-- the amphitheatre Papalymo (1000010 is the Man-quest one)
local URIANGER				= 1500204
local AMPHITHEATRE_TRIGGER	= 1090332
local ROOTSLAKE_TRIGGER		= 1090333

local MRKR_AMPHITHEATRE		= 11160401
local MRKR_PAPALYMO			= 11160402
local MRKR_ROOTSLAKE			= 11160403
local MRKR_URIANGER			= 11160404

local PAPALYMO_POS			= {-89.5, 16.5, -1606.0, -2.27}

local DUTY_ZONE				= 154	-- South Shroud
local DUTY_AREA				= "SimpleContentCom0g501"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0g501"
local DUTY_ANCHOR				= {1598.0, -0.4, 1268.0, 0.76}
local TRIGGER_RETURN			= {1594.0, -0.3, 1263.0, 0.76}		-- outside the push circle
local URIANGER_RETURN			= {1628.0, 0.1, 1277.0, 1.52}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(FULKE, QFLAG_TALK)
		return
	end

	quest:SetENpc(FULKE)
	-- isSpawned: these story actors exist only for players on this quest.
	quest:SetENpc(PAPALYMO, sequence == SEQ_001 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence >= SEQ_001)
	quest:SetENpc(URIANGER, sequence == SEQ_003 and QFLAG_REWARD or QFLAG_OFF, true, false, false, sequence >= SEQ_002)
	if sequence == SEQ_000 then
		quest:SetENpc(AMPHITHEATRE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_002 then
		quest:SetENpc(ROOTSLAKE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[FULKE] = function(player, quest)
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeStart")
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_001] = {
		[PAPALYMO] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent011")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent012")
			quest:StartSequence(SEQ_002)
		end,
	},
	[SEQ_003] = {
		[URIANGER] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "followEvent005")
		end,
		[PAPALYMO] = function(player, quest)
			if quest:GetSequence() < SEQ_002 then return end
			local data = quest:GetData()
			local page = data:GetCounter(0) % 3
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020", page)
			data:IncCounter(0)
			data:Save()
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

local push = {
	[SEQ_000] = {
		[AMPHITHEATRE_TRIGGER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005")
			quest:StartSequence(SEQ_001)
			player:EndEvent()
			local p = PAPALYMO_POS
			GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, p[1], p[2], p[3], p[4])
			return true
		end,
	},
	[SEQ_002] = {
		[ROOTSLAKE_TRIGGER] = function(player, quest, npc)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startQuestDuty(player, quest, {
					zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
					anchor = DUTY_ANCHOR
				})
				return true
			end
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
end

-- Called by QuestDirectorCom0g501 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_002 then
		return
	end

	if success then
		wait(2)
		quest:StartSequence(SEQ_003)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		endQuestDuty(player, duty, DUTY_ZONE, URIANGER_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	local sequence = quest:GetSequence()
	local invitation = (sequence <= SEQ_001) and 1 or 0	-- Papalymo's talk ends its use
	local earthbreaker = (sequence >= SEQ_002) and 1 or 0
	return invitation, earthbreaker
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return MRKR_AMPHITHEATRE
	elseif sequence == SEQ_001 then
		return MRKR_PAPALYMO
	elseif sequence == SEQ_002 then
		return MRKR_ROOTSLAKE
	elseif sequence == SEQ_003 then
		return MRKR_URIANGER
	end
end
