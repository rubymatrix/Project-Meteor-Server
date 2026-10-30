require("Global")
require("Quest")

--[[

Quest Script

Name: 	The House Always Wins
Code: 	Pgl200
Id: 	110060
Prereq: Level 20, Pugilist

]]

-- Sequence Numbers
local SEQ_000	= 0   -- Talk to Titinin.
local SEQ_005	= 5   -- Head to the GSM guild and talk to Esperaunce 3 times.
local SEQ_010	= 10  -- Warp into a duty; pickup coins.
local SEQ_015	= 15  -- Head to the ADV guild and talk to the Wise Miser. Journal Data 3: Set to 1 if talked to Titinin.
local SEQ_025	= 25  -- Head to the PGL guild entrence and talk to Lady Lewena. Journal Data 4: Set to 1 if talked to Titinin.
local SEQ_030	= 30  -- Head to GLA guild and warp into the duty and fight. Journal Data 5: Set to 1 once you win the fight.
local SEQ_035	= 35  -- Return to Titinin.

-- Actor Class Ids
local ENPC_GAGARUNA 		= 1000862
local ENPC_TITININ 		= 1000934
local ENPC_NAIDA_ZAMAIDA	= 1000955
local ENPC_SINGLETON		= 1001445
local ENPC_TRIGGER_GSM	= 1090058
local ENPC_TRIGGER_PGL	= 1090042
local ENPC_PRIVAREA_EXIT	= 1290002

-- PGL Actors
local ENPC_MELISIE		= 1001009
local ENPC_GUNNULF		= 1001256
local ENPC_SHAMANI 		= 1001012
local ENPC_HALSTEIN		= 1001007
local ENPC_HEIBERT		= 1001257
local ENPC_IPAGHLO		= 1001260

-- GSM Actors
local ENPC_SULTRY_STRUMPET 	= 1000952
local ENPC_BEAUTEOUS_BEAUTY 	= 1000953
local ENPC_ESPERAUNCE			= 1000954

-- Quest Markers
local MRKR_TITININ		= 11006001
local MRKR_OBJECTIVE		= 11006002
local MRKR_ESPERAUNCE1	= 11006003
local MRKR_ESPERAUNCE2	= 11006004
local MRKR_NAIDA_ZAMADIA	= 11006005
local MRKR_OBJECTIVE2		= 11006006
local MRKR_SINGLETON		= 11006007
local MRKR_TITININ2		= 11006008

-- Quest Details
local ITEM_PLATINUM_LEDGER  = 11000134
local ITEM_KINGOFPLOTS_GIL  = 11000097
local ITEM_WISEMISER_GIL    = 11000098
local ITEM_LEWENA_GIL  	  = 11000099
local COUNTER_005 = 0
local COUNTER_015 = 1
local COUNTER_025 = 2
local COUNTER_030 = 3

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK)
	elseif sequence == SEQ_000 then
		quest:SetENpc(ENPC_TITININ, QFLAG_TALK)
		quest:SetENpc(ENPC_GAGARUNA)
		quest:SetENpc(ENPC_MELISIE)
		quest:SetENpc(ENPC_GUNNULF)
		quest:SetENpc(ENPC_SHAMANI)
		quest:SetENpc(ENPC_HALSTEIN)
		quest:SetENpc(ENPC_HEIBERT)
		quest:SetENpc(ENPC_IPAGHLO)
	elseif sequence == SEQ_005 then
		quest:SetENpc(ENPC_TITININ)
		quest:SetENpc(ENPC_GAGARUNA)
		quest:SetENpc(ENPC_SULTRY_STRUMPET)
		quest:SetENpc(ENPC_BEAUTEOUS_BEAUTY)
		quest:SetENpc(ENPC_ESPERAUNCE, QFLAG_TALK)
		quest:SetENpc(ENPC_TRIGGER_GSM, QFLAG_OFF, false, true)
		quest:SetENpc(ENPC_PRIVAREA_EXIT, QFLAG_OFF, false, true)
	elseif sequence == SEQ_010 then
		quest:SetENpc(ENPC_SULTRY_STRUMPET)
		quest:SetENpc(ENPC_BEAUTEOUS_BEAUTY)
		quest:SetENpc(ENPC_ESPERAUNCE)
	elseif sequence == SEQ_015 then
		quest:SetENpc(ENPC_TITININ)
		quest:SetENpc(ENPC_NAIDA_ZAMAIDA, QFLAG_TALK)
		quest:SetENpc(ENPC_GAGARUNA)
	elseif sequence == SEQ_025 then
		quest:SetENpc(ENPC_TITININ)
		quest:SetENpc(ENPC_GAGARUNA)
		quest:SetENpc(ENPC_TRIGGER_PGL, QFLAG_PUSH, false, true)
	elseif sequence == SEQ_030 then
		quest:SetENpc(ENPC_TITININ)
		quest:SetENpc(ENPC_GAGARUNA)
		quest:SetENpc(ENPC_SINGLETON, QFLAG_TALK)
	elseif sequence == SEQ_035 then
		quest:SetENpc(ENPC_TITININ, QFLAG_REWARD)
		quest:SetENpc(ENPC_GAGARUNA)
		quest:SetENpc(ENPC_MELISIE)
		quest:SetENpc(ENPC_GUNNULF)
		quest:SetENpc(ENPC_SHAMANI)
		quest:SetENpc(ENPC_HALSTEIN)
		quest:SetENpc(ENPC_HEIBERT)
		quest:SetENpc(ENPC_IPAGHLO)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		-- Offer the quest
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGagarunaStart")
			if questAccepted == 1 then
				player:AcceptQuest(quest)
			end
			player:EndEvent()
			return true
		end,
	},
	-- Quest Progress
	[SEQ_000] = {
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010")
			player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_PLATINUM_LEDGER, 1)
			quest:StartSequence(SEQ_005)
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2")
		end,
		[ENPC_IPAGHLO] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_3")
		end,
		[ENPC_HALSTEIN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_4")
		end,
		[ENPC_MELISIE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_5")
		end,
		[ENPC_HEIBERT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_6")
		end,
		[ENPC_GUNNULF] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_7")
		end,
		[ENPC_SHAMANI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_8")
		end,
	},
	[SEQ_005] = {
		[ENPC_ESPERAUNCE] = function(player, quest, npc, eventName)
			local data = quest:GetData()
			local talkCount = data:IncCounter(COUNTER_005)
			if talkCount == 1 then
				player:SendGameMessage(quest, 117, MESSAGE_TYPE_SYSTEM)
			elseif talkCount == 2 then
				player:SendGameMessage(quest, 118, MESSAGE_TYPE_SYSTEM)
			elseif talkCount >= 3 then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent020")
				quest:StartSequence(SEQ_010) -- Temp until Duty is finished. Should go to a duty here.
			end
		end,
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2")
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3")
		end,
		[ENPC_SULTRY_STRUMPET] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_4")
		end,
		[ENPC_BEAUTEOUS_BEAUTY] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_5")
		end,
	},
	[SEQ_010] = {
		[ENPC_ESPERAUNCE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030")
			quest:StartSequence(SEQ_015) -- Temp until Duty is finished.
			player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_KINGOFPLOTS_GIL, 1)
			player:EndEvent()
			GetWorldManager():WarpToPublicArea(player)
			return true
		end,
		[ENPC_SULTRY_STRUMPET] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
		end,
		[ENPC_BEAUTEOUS_BEAUTY] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
		end,
	},
	[SEQ_015] = {
		[ENPC_NAIDA_ZAMAIDA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040")
			quest:StartSequence(SEQ_025)
			player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_WISEMISER_GIL, 1)
		end,
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			local data = quest:GetData()
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2")
			data:SetCounter(COUNTER_015, 1)
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_3")
		end,
	},
	[SEQ_025] = {
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			local data = quest:GetData()
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2")
			data:SetCounter(COUNTER_025, 1)
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_3")
		end,
	},
	[SEQ_030] = {
		[ENPC_SINGLETON] = function(player, quest, npc, eventName)
			local data = quest:GetData()
			local enterDuty = callClientFunction(player, "delegateEvent", player, quest, "processEvent050_4")
			if enterDuty == 1 then
				--Enter duty at this point....
				callClientFunction(player, "delegateEvent", player, quest, "processEvent060")
				data:SetCounter(COUNTER_030, 1)
				quest:StartSequence(SEQ_035) -- Temp until Duty is finished.
				player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_LEWENA_GIL, 1)
				GetWorldManager():DoZoneChange(player, 209, nil, 0, 0x2, -192.0, 194.5, 193.785, 3.0)
			end
		end,
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2")
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_3")
		end,
	},
	[SEQ_035] = {
		[ENPC_TITININ] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent070")
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 2)
			player:CompleteQuest(quest)
		end,
		[ENPC_GAGARUNA] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_2")
		end,
		[ENPC_IPAGHLO] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_3")
		end,
		[ENPC_HALSTEIN] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_4")
		end,
		[ENPC_MELISIE] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_5")
		end,
		[ENPC_HEIBERT] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_6")
		end,
		[ENPC_GUNNULF] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_7")
		end,
		[ENPC_SHAMANI] = function(player, quest, npc, eventName)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_8")
		end,
	},
}

function onTalk(player, quest, npc, eventName)
	if runQuestHandler(talk, player, quest, npc, eventName) then return end

	quest:UpdateENPCs()
	player:EndEvent()
end

function onPush(player, quest, npc)
	local npcClassId = npc:GetActorClassId()
	local seq = quest:GetSequence()
	local data = quest:GetData()

	if seq == SEQ_005 then
		player:EndEvent()
		if npcClassId == ENPC_TRIGGER_GSM then
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 5)
		elseif npcClassId == ENPC_PRIVAREA_EXIT then
			GetWorldManager():WarpToPublicArea(player)
		end
	elseif seq == SEQ_025 then
		if npcClassId == ENPC_TRIGGER_PGL then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050")
			quest:StartSequence(SEQ_030)
			player:EndEvent()
		end
	end

end

function getJournalInformation(player, quest)
	local data = quest:GetData()
	return 0, data:GetCounter(COUNTER_015), data:GetCounter(COUNTER_025), data:GetCounter(COUNTER_030)
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence()
	local data = quest:GetData()

	if seq == SEQ_000 then
		return MRKR_TITININ
	elseif seq == SEQ_005 then
		return MRKR_ESPERAUNCE1
	elseif seq == SEQ_010 then
		return MRKR_OBJECTIVE
	elseif seq == SEQ_015 then
		if data:GetCounter(COUNTER_015) == 1 then
			return MRKR_NAIDA_ZAMADIA
		end
	elseif seq == SEQ_025 then
		if data:GetCounter(COUNTER_025) == 1 then
			return MRKR_OBJECTIVE2
		end
	elseif seq == SEQ_030 then
		return MRKR_SINGLETON
	elseif seq == SEQ_035 then
		return MRKR_TITININ2
	end

	return
end