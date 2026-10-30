require("Global")

--[[
Disbands the party (same as PartyBreakupCommand). Text 30540 tells a non-leader they can't.
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
