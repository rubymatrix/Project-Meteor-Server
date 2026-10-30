--[[
Cancels the player's pending linkshell invite.
--]]

function onEventStarted(player, actor, eventType, eventName, arg1, arg2, arg3, arg4, actorId)

	GetWorldManager():RequestWorldLinkshellCancelInvite(player)
	player:EndEvent()

end