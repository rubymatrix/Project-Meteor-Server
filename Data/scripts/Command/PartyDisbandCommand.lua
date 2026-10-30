require("Global")

--[[

PartyDisbandCommand Script

Handles disbanding the party (same as PartyBreakupCommand).

TextIds:

30540 - You are not party leader

--]]

function onEventStarted(player, actor, eventType, eventName)
	worldMaster = GetWorldMaster()

	if player:IsPartyLeader() then
		player:PartyDisband()
	else
		player:SendGameMessage(player, worldMaster, 30540, 0x20)
	end

	player:EndEvent()
end
