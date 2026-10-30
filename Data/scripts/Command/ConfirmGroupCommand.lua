--[[
Answering an invite to a group.
--]]

function onEventStarted(player, actor, eventType, eventName, groupType, result)

	--Accept/Refuse happened, else just close the window
	if result == 1 or result == 2 then
		GetWorldManager():GroupInviteResult(player, groupType, result)
	end

	player:EndEvent()

end