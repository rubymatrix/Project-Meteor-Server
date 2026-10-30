require("Global")

--[[
Logout menu: 1 quits the game, 2 logs out. The client also has
eventCountDown and eventLogoutFade, which the server doesn't use.
--]]

function onEventStarted(player, command, eventType, eventName)

	local choice = callClientFunction(player, "delegateCommand", command, "eventConfirm")

	if choice == 1 then
		player:QuitGame()
	elseif choice == 2 then
		player:Logout()
	end

	player:EndEvent()

end
