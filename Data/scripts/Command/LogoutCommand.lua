--[[

LogoutCommand Script

Functions:

eventConfirm()
eventCountDown()
eventLogoutFade()

--]]

require("Global")

function onEventStarted(player, command, eventType, eventName)

	choice = callClientFunction(player, "delegateCommand", command, "eventConfirm")

	if choice == 1 then
		player:QuitGame()
	elseif choice == 2 then
		player:Logout()
	end

	player:EndEvent()

end
