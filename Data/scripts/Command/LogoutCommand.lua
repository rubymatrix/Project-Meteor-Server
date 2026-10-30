require("Global")

--[[

LogoutCommand Script

Functions:

eventConfirm()
eventCountDown()
eventLogoutFade()

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
