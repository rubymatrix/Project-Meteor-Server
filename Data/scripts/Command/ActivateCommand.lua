require("Global")

--[[
Switches between active and passive mode states.
--]]

function onEventStarted(player, command, eventType, eventName)

	if player.currentMainState == 0x0000 then
		player:Engage(0, 0x0002)
	elseif player.currentMainState == 0x0002 then
		player:Disengage(0x0000)
	end
	player:EndEvent()
	sendSignal("playerActive")
end