require("Global")
require("Quest")

--[[
Dressed to Be Killed (Etc1u2, 110677). Level 45, any DoW/DoM.
--]]

-- Sequence Numbers
local SEQ_000	= 0  -- Kill Dapper Cadaver.
local SEQ_001	= 1  -- Talk to Tutubuki.

-- Actor Class Ids
local ENPC_TUTUBUKI 		= 1001141
local BNPC_DAPPER_CADAVER	= 2101816

-- Quest Markers
local MRKR_CADAVER_AREA	= 11067701
local MRKR_TUTUBUKI		= 11067702

-- Quest Details
local OBJECTIVE_ITEMID	= 11000155

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_TUTUBUKI, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_TUTUBUKI)
		quest:SetENpc(BNPC_DAPPER_CADAVER)
	elseif sequence == SEQ_001 then
		quest:SetENpc(ENPC_TUTUBUKI, QFLAG_REWARD)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_TUTUBUKI] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventTutubukiStart", 0, OBJECTIVE_AMOUNT)
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_TUTUBUKI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2", 0, OBJECTIVE_AMOUNT)
		end,
	},
	--Quest Complete
	[SEQ_001] = {
		[ENPC_TUTUBUKI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9)
			player:CompleteQuest(quest)
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onKillBNpc(player, quest, bnpc)
	if bnpc == BNPC_DAPPER_CADAVER then
		player:SendGameMessage(GetWorldMaster(), 50041, 0x20, 3101818, 1, 1) -- The <dispName> has been defeated. (X of Y)
		player:SendGameMessage(GetWorldMaster(), 25246, 0x20, OBJECTIVE_ITEMID, 1) -- You obtain <item>
		attentionMessage(player, 25225, quest:GetQuestId()) -- Objectives complete!
		quest:StartSequence(SEQ_001)
	end
end

function getJournalInformation(player, quest)
	return quest:GetData():GetCounter(COUNTER_QUESTITEM)
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()

	if sequence == SEQ_000 then
		return MRKR_CADAVER_AREA
	elseif sequence == SEQ_001 then
		return MRKR_TUTUBUKI
	end
end