--[[
Hands party leadership to another member, by name or actor id.
--]]

function onEventStarted(player, actor, eventType, eventName, name, arg2, arg3, arg4, actorId)
	worldMaster = GetWorldMaster()

	if player:IsPartyLeader() then
		if name == nil then
			player:PartyPromote(actorId)
		else
			player:PartyPromote(name)
		end
	else
		player:SendGameMessage(player, worldMaster, 30540, 0x20)
	end

	player:EndEvent()
end