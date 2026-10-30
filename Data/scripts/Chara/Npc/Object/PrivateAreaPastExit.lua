require("Global")

--[[

PrivateAreaPastExit

This object contains the player inside a PrivateAreaPast, stopping them from escaping it's bounds. It is the
object that generates the circle graphic on the minimap. This object always has two push triggers, an inner
and outer inverted circle. The inner one is named "caution" and the outer one is named "exit". When the player
leaves the inner circle a warning is shown and when they leave the outer circle they either leave the instance
or get warped back to the center.

]]

function init(privAreaExit)
	return false, false, 0, 0
end

function onEventStarted(player, privAreaExit, eventType, eventName)
	player:EndEvent()

	if eventName == "caution" then
		player:SendGameMessage(player, GetWorldMaster(), 34109, MESSAGE_TYPE_SYSTEM) -- You are about to leave the instance.
	elseif eventName == "exit" then
		local area = privAreaExit.CurrentArea
		if area:IsPrivate() then
			-- If you can leave, warp to public zone and show message.
			if area:CanExitPrivateArea() then
				player:SendGameMessage(player, GetWorldMaster(), 34110, MESSAGE_TYPE_SYSTEM) -- You have left the instance.
				--GetWorldManager():WarpToPublicArea(player);
			-- Otherwise warp back to the center of the zone.
			else
				--GetWorldManager():WarpToCharaPosition(player, privAreaExit);
			end
		end
	end
end