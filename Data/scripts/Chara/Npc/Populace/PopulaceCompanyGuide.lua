require("Global")

--[[
Grand Company representatives: picks the dialog from the player's company and rank.
--]]

function init(npc)
	return false, false, 0, 0
end

local gcRep = {
	[1001737] = 1, -- Maelstrom Representative
	[1001738] = 2, -- Adder Representative
	[1001739] = 3, -- Flame Representative
}

function onEventStarted(player, npc, triggerName)
	local playerGc = player.gcCurrent
	local playerGcRanks = {player.gcRankLimsa, player.gcRankGridania, player.gcRankUldah}
	local npcGc = gcRep[npc:GetActorClassId()]

	if playerGc ~= npcGc and playerGcRanks[playerGc] == 127 then
		callClientFunction(player, "eventTalkWelcome")
	elseif playerGc == npcGc and playerGcRanks[playerGc] == 127 then
		callClientFunction(player, "eventTalkProvisional")
	elseif playerGc ~= npcGc and playerGcRanks[playerGc] ~= 127 then
		callClientFunction(player, "eventTalkExclusive")
	elseif playerGc == npcGc and playerGcRanks[playerGc] > 10 and playerGcRanks[playerGc] < 112 then
		callClientFunction(player, "eventTalkComMember", nil, npc, true)
	end

	callClientFunction(player, "eventTalkStepBreak")
	player:EndEvent()
end

