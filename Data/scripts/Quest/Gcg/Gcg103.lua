require("Global")
require("Quest")
require("QuestDuty")

--[[
Shadow of the Raven (Gcg103, 111629). After Gcg102; level 45, Twin Adder rank 11.
The magitek vanguard fight (QuestDirectorGcg10301) completes the quest on a win: the client has no
turn-in function. A loss or a full inventory keeps SEQ_010, and Swethyna restarts it.
--]]

local startDuty


local SEQ_000 = 0
local SEQ_005 = 5
local SEQ_010 = 10

local FULKE		= 1500200
local KANESENNA	= 1001569
local SWETHYNA	= 1000680
local OAPPPESI	= 1000033
local BROOKSTONE	= 1060025	-- the client names this one Swethryk

local DUTY_ZONE		= 153	-- West Shroud
local DUTY_AREA		= "SimpleContentGcg10301"
local DUTY_DIRECTOR	= "Quest/QuestDirectorGcg10301"
local DUTY_ANCHOR		= {-1570.0, -11.0, -520.0, 2.9}
local SITE_RETURN		= {-1570.0, -11.0, -520.0, 2.9}

local CLASS_CNJ = 23

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
	if sequence == SEQ_COMPLETE then
		return
	end
	quest:SetENpc(FULKE)
	-- isSpawned: these story actors exist only for players on these steps.
	quest:SetENpc(KANESENNA, sequence == SEQ_000 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence == SEQ_000)
	quest:SetENpc(SWETHYNA, sequence >= SEQ_005 and QFLAG_TALK or QFLAG_OFF, true, false, false, sequence >= SEQ_005)
	quest:SetENpc(OAPPPESI)
	quest:SetENpc(BROOKSTONE, QFLAG_OFF, true, false, false, sequence == SEQ_000)
end

local function noTalk() end

local talk = {
	[SEQ_ACCEPT] = {
		[FULKE] = function(player, quest)
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return true
		end,
		[OAPPPESI] = noTalk,
		[BROOKSTONE] = noTalk,
	},
	[SEQ_000] = {
		[KANESENNA] = function(player, quest)
			local gridanian = player:GetInitialTown() == 2 and 1 or 0
			local whiteMage = (player:GetClass() == CLASS_CNJ and player.currentJob ~= 0) and 1 or 0
			callClientFunction(player, "delegateEvent", player, quest, "processEventSenna", gridanian, whiteMage)
			quest:StartSequence(SEQ_005)
		end,
	},
	[SEQ_005] = {
		[SWETHYNA] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01", 0)
			quest:StartSequence(SEQ_010)
			startDuty(player, quest)
			return true
		end,
	},
	[SEQ_010] = {
		[SWETHYNA] = function(player, quest)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startDuty(player, quest)
				return true
			end
		end,
	},
	always = {
		[FULKE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter")
		end,
		[OAPPPESI] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventPesi")
		end,
		[BROOKSTONE] = function(player, quest)
			callClientFunction(player, "delegateEvent", player, quest, "processEventSwethryk")
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
end

function startDuty(player, quest)
	startQuestDuty(player, quest, {
		zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
		anchor = DUTY_ANCHOR
	})
end

-- Called by QuestDirectorGcg10301 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_010 then
		return
	end
	if success then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ02")
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then
			player:CompleteQuest(quest)
		end
		-- A full inventory keeps SEQ_010: Swethyna restarts the fight.
		endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
		return
	end
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, DUTY_ZONE, SITE_RETURN)
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
