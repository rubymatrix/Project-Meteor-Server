require("Global")

--[[

BazaarCheckCommand Script

Handles what happens when you examine a player's bazaar

--]]

function onEventStarted(player, actor, eventType, eventName, name, arg1, arg2, arg3, bazaarActorId)

	local bazaarActor = nil

	if name ~= nil then
		bazaarActor = player.CurrentArea:FindPCInZone(name)
	elseif bazaarActorId ~= nil then
		bazaarActor = player.CurrentArea:FindActorInArea(bazaarActorId)
	end

	if bazaarActor ~= nil then
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "", "Currently disabled due to freezing characters.")
		--callClientFunction(player, "delegateCommand", GetStaticActor("BazaarCheckCommand"), "processChackBazaar");
	else
		--Show error
	end

	player:EndEvent()

end