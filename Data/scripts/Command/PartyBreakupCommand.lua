--[[
Disbands the party; only the leader may.
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