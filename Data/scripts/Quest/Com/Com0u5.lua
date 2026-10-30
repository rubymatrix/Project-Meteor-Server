require("Global")
require("Quest")
require("QuestDuty")

--[[
Burning Man (Com0u5, 111805). Prereq: Com0u4; level 25.
Thancred and Urianger use unspawned classes that carry their names.
Walkthrough: Data/Docs/Scripts/Quest/Com/Com0u5.md.
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

local function delegate(player, quest, fn, ...)
	callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

local talk = {
	[SEQ_ACCEPT] = {
		[AUBREY] = function(player, quest)
			if callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyStart") == 1 then
				player:AcceptQuest(quest)
			end
		end,
	},
	[SEQ_001] = {
		[THANCRED_DOCKS] = function(player, quest)
			delegate(player, quest, "processEvent010")
			quest:StartSequence(SEQ_002)
		end,
		[URIANGER_DOCKS] = function(player, quest) delegate(player, quest, "processEvent010_2") end,
	},
	[SEQ_002] = {
		[AUBREY] = function(player, quest)
			delegate(player, quest, "processEvent015")
			quest:StartSequence(SEQ_003)
		end,
	},
	[SEQ_003] = {
		[AUBREY] = function(player, quest) delegate(player, quest, "processEvent020") end,
	},
	[SEQ_004] = {
		[AUBREY] = function(player, quest) delegate(player, quest, "processEvent020") end,
		[THANCRED_PROMENADE] = function(player, quest)
			-- 0 plays the main path.
			delegate(player, quest, "processEvent030", 0)
			local rewarded = showQuestRewards(player, quest)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest) end
			return true
		end,
	},
	always = {
		[AUBREY] = function(player, quest) delegate(player, quest, "processEvent000_2") end,
		[THANCRED_DOCKS] = function(player, quest) delegate(player, quest, "processEvent015_2") end,
		[URIANGER_DOCKS] = function(player, quest) delegate(player, quest, "processEvent015_3") end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
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
			-- Raubahn's address plays in place on the Promenade: no warp.
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
