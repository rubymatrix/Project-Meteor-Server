--[[
The player's answer to a trade: accept or refuse.
--]]

function onEventStarted(player, actor, eventType, eventName, groupType, result)

	--Accept
	if result == 1 then
		GetWorldManager():AcceptTrade(player)
	--Refuse
	elseif result == 2 then
		GetWorldManager():RefuseTrade(player)
	end
	player:EndEvent()

end