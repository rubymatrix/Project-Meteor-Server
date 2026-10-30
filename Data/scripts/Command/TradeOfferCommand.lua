--[[
Offers a trade to another player, found by actor id or else by name.
--]]

function onEventStarted(player, actor, eventType, eventName, name, arg1, arg2, arg3, actorId)

	local otherActor = nil

	if actorId ~= nil then
		otherActor = player.CurrentArea:FindActorInArea(actorId)
	elseif name ~= nil then
		otherActor = player.CurrentArea:FindPCInZone(name)
	end

	if otherActor ~= nil then
		GetWorldManager():CreateTradeGroup(player, otherActor)
	else
	end

	player:EndEvent()
end