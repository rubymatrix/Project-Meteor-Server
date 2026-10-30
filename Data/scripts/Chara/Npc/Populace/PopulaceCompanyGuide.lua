require("Global")

--[[

PopulaceCompanyGuide Script

Functions:

eventTalkWelcome()                              - Dialog for new recruits
eventTalkProvisional()                          - Message for when rank isn't high enough?
eventTalkExclusive()                            - Message for wrong GC.
eventTalkComMember(nil, npc, isFoundationDay)   - Information menus for various GC related activities
eventTalkStepBreak()                            - Returns to NPC's neutral state

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

