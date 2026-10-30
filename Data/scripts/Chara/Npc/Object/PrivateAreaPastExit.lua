require("Global")

--[[
Keeps the player inside a PrivateAreaPast and draws its circle on the minimap. Two inverted-circle
push triggers: leaving the inner "caution" one warns, leaving the outer "exit" one either leaves the
instance or warps the player back to the centre.
--]]

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