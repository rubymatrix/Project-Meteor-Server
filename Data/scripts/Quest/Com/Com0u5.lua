require("Global")
require("Quest")
require("QuestDuty")

--[[
Burning Man (Com0u5, 111805). After Com0u4. Level 25.

 - Offer, Aubrey: processEventAubreyStart (1 = accepted). Repeat processEvent000_2.
 - SEQ_000 push at the ferry docks west of Camp Horizon: join ask, the pirates (QuestDirectorCom0u501)
   -> SEQ_001.
 - SEQ_001 Thancred at the docks: processEvent010 -> SEQ_002. Urianger: processEvent010_2.
 - SEQ_002 Aubrey: processEvent015 -> SEQ_003. Thancred / Urianger repeat processEvent015_2 / _3.
 - SEQ_003 push on the Royal Promenade: processEvent025 (Raubahn's address) -> SEQ_004. Aubrey
   repeats processEvent020.
 - SEQ_004 Thancred after the speech: processEvent030(0), rewards, complete.
Which handler belongs to which NPC follows the handler order and the journal. Not wired:
processEventAubreyHint and the dock crowd (processEvent010_3.._6, 020_2/_3, 030_2.._6). Thancred and
Urianger use unspawned classes that carry their names.
--]]

local SEQ_000	= 0
local SEQ_001	= 1
local SEQ_002	= 2
local SEQ_003	= 3
local SEQ_004	= 4

local AUBREY					= 1500198
local THANCRED_DOCKS			= 1500037
local URIANGER_DOCKS			= 1500314
local THANCRED_PROMENADE		= 1500030
local PIRATE_TRIGGER			= 1090336
local PROMENADE_TRIGGER		= 1090337

local DUTY_ZONE				= 172	-- Western Thanalan
local DUTY_AREA				= "SimpleContentCom0u501"
local DUTY_DIRECTOR			= "Quest/QuestDirectorCom0u501"
local DUTY_ANCHOR				= {-2169.96, 14.25, -430.79, 0.3}
local TRIGGER_RETURN			= {-2172.40, 14.33, -432.50, 0.3}	-- outside the push circle

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

	quest:SetENpc(AUBREY, sequence == SEQ_002 and QFLAG_TALK or QFLAG_OFF)
	if sequence == SEQ_000 then
		quest:SetENpc(PIRATE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	elseif sequence == SEQ_003 then
		quest:SetENpc(PROMENADE_TRIGGER, QFLAG_PUSH, false, true, false, true)
	end
	-- isSpawned: these story actors exist only for players on these steps.
	local atDocks = (sequence == SEQ_001 or sequence == SEQ_002)
	quest:SetENpc(THANCRED_DOCKS, sequence == SEQ_001 and QFLAG_TALK or QFLAG_OFF, true, false, false, atDocks)
	quest:SetENpc(URIANGER_DOCKS, QFLAG_OFF, true, false, false, atDocks)
	quest:SetENpc(THANCRED_PROMENADE, sequence == SEQ_004 and QFLAG_REWARD or QFLAG_OFF, true, false, false, sequence == SEQ_004)
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	local function talk(fn, ...)
		callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if classId == AUBREY then
		if sequence == SEQ_ACCEPT then
			if callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyStart") == 1 then
				player:AcceptQuest(quest)
			end
		elseif sequence == SEQ_002 then
			talk("processEvent015")
			quest:StartSequence(SEQ_003)
		elseif sequence == SEQ_003 or sequence == SEQ_004 then
			talk("processEvent020")
		else
			talk("processEvent000_2")
		end
	elseif classId == THANCRED_DOCKS then
		if sequence == SEQ_001 then
			talk("processEvent010")
			quest:StartSequence(SEQ_002)
		else
			talk("processEvent015_2")
		end
	elseif classId == URIANGER_DOCKS then
		talk(sequence == SEQ_001 and "processEvent010_2" or "processEvent015_3")
	elseif classId == THANCRED_PROMENADE and sequence == SEQ_004 then
		-- 0 plays the main path.
		talk("processEvent030", 0)
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

local push = {
	[SEQ_000] = {
		[PIRATE_TRIGGER] = function(player, quest, npc)
			if callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass") == 1 then
				startQuestDuty(player, quest, {
					zone = DUTY_ZONE, area = DUTY_AREA, director = DUTY_DIRECTOR,
					anchor = DUTY_ANCHOR
				})
				return true
			end
		end,
	},
	[SEQ_003] = {
		[PROMENADE_TRIGGER] = function(player, quest, npc)
			-- The cutscene plays in place; the player stays on the Promenade.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025")
			quest:StartSequence(SEQ_004)
		end,
	},
}

function onPush(player, quest, npc)
	if runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorCom0u501 when the fight ends.
function onDutyComplete(player, quest, director, duty, success, reason)
	if quest:GetSequence() ~= SEQ_000 then
		return
	end

	if success then
		wait(2)
		quest:StartSequence(SEQ_001)
	elseif reason == "left" then
		endQuestDuty(player, duty)
		return
	else
		wait(3)
	end
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
	endQuestDuty(player, duty, DUTY_ZONE, TRIGGER_RETURN)
end

function getJournalInformation(player, quest)
	return 0
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		return 11170401				-- the docks
	elseif sequence == SEQ_001 then
		return 11170402, 11170403		-- Thancred, Urianger
	elseif sequence == SEQ_002 then
		return 11170404				-- Aubrey
	elseif sequence == SEQ_003 then
		return 11170405				-- the Royal Promenade
	elseif sequence == SEQ_004 then
		return 11170406				-- Thancred
	end
end
