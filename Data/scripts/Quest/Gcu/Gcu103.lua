require("Global")
require("Quest")
require("QuestDuty")

--[[
Careless Whispers (Gcu103, 111829). After Gcu102. Level 45, Immortal Flames rank 11.

 - Offer, Aubrey: processEvent_000_AUBREYStart (1 = accepted). Repeat processEvent_000_AUBREYFollow.
 - SEQ_000 the Royal Promenade: Grand Flame Marshal Roaille (Eline) processEvent_000_ELINEAfterOffer;
   Raubahn processEvent_005_RAUBAHN (go west of Camp Horizon) -> SEQ_005.
 - SEQ_005 push west of Camp Horizon: processEvent_010_NQ_1(0) (the Flames are nigh wiped out)
   -> SEQ_010.
 - SEQ_010 push again, join ask, the new juggernaut (QuestDirectorGcu10301). Win -> SEQ_020, back
   outside. The wounded Flames (processEvent_015_FUMETSU01.._05) are not wired: their classes are not
   known.
 - SEQ_020 it was a diversion; push at the Vesper Bay ferry docks: processEvent_025_NQ_2(0), rewards,
   complete. There is no turn-in function.
No markers.
--]]

local SEQ_000	= 0
local SEQ_005	= 5
local SEQ_010	= 10
local SEQ_020	= 20

local AUBREY					= 1500198
local ELINE					= 1060026	-- Grand Flame Marshal Roaille
local RAUBAHN					= 1002051
local HORIZON_TRIGGER			= 1090339	-- shares its class with Com0u6's trigger; each quest has its own spawn
local DOCKS_TRIGGER			= 1090363

local DUTY_ZONE				= 172	-- Western Thanalan
local DUTY_AREA				= "SimpleContentGcu10301"
local DUTY_DIRECTOR			= "Quest/QuestDirectorGcu10301"
local DUTY_ANCHOR				= {-1505.0, 49.0, -140.0, -1.57}
local TRIGGER_RETURN			= {-1495.0, 48.19, -145.0, -1.57}	-- outside the push circle

local FLAG_SCENE				= 0	-- the docks scene played but the inventory was full: rewards still owed

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
	-- isSpawned: these story actors exist only for players on this step.
	local onPromenade = sequence == SEQ_000
	quest:SetENpc(ELINE, QFLAG_OFF, true, false, false, onPromenade)
	quest:SetENpc(RAUBAHN, onPromenade and QFLAG_TALK or QFLAG_OFF, true, false, false, onPromenade)
	if sequence == SEQ_005 or sequence == SEQ_010 then
		quest:SetENpc(HORIZON_TRIGGER, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_020 then
		quest:SetENpc(DOCKS_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	local function talk(fn, ...)
		return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if classId == AUBREY then
		if sequence == SEQ_ACCEPT then
			if talk("processEvent_000_AUBREYStart") == 1 then
				player:AcceptQuest(quest)
			end
		else
			talk("processEvent_000_AUBREYFollow")
		end
	elseif classId == ELINE and sequence == SEQ_000 then
		talk("processEvent_000_ELINEAfterOffer")
	elseif classId == RAUBAHN and sequence == SEQ_000 then
		talk("processEvent_005_RAUBAHN")
		quest:StartSequence(SEQ_005)
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

local function finish(player, quest)
	local rewarded = showQuestRewards(player, quest)
	player:EndEvent()
	if rewarded then
		player:CompleteQuest(quest)
	else
		setQuestFlag(quest, FLAG_SCENE)
	end
end

local push = {
	[SEQ_005] = {
		[HORIZON_TRIGGER] = function(player, quest, npc)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_NQ_1", 0)
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_010] = {
		[HORIZON_TRIGGER] = function(player, quest, npc)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startQuestDuty(player, quest, {
					zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
					anchor = DUTY_ANCHOR
				})
				return true
			end
		end,
	},
	[SEQ_020] = {
		[DOCKS_TRIGGER] = function(player, quest, npc)
			-- Rewards that did not fit: the scene stands and the push pays out next time.
			if not questFlag(quest, FLAG_SCENE) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent_025_NQ_2", 0)
			end
			finish(player, quest)
			return true
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorGcu10301 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_010 then
		return
	end
	if success then
		wait(2)
		quest:StartSequence(SEQ_020)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
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
	return 0
end

function getJournalMapMarkerList(player, quest)
end
