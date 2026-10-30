--[[
Party invites.
--]]

function onEventStarted(player, actor, eventType, eventName, name, arg1, arg2, arg3, actorId)

	if name ~= nil then
		GetWorldManager():CreateInvitePartyGroup(player, name)
	elseif actorId ~= nil then
		GetWorldManager():CreateInvitePartyGroup(player, actorId)
	end

	player:EndEvent()

end