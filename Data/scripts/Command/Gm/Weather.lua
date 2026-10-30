require("Global")

--[[
Functions: onTrigger
Desc:   Changes the weather you see; ids 1-81 are taken as 8001-8081.
Params: <id> [<transition>] [<zonewide>]
--]]

properties = {
	permissions = 0,
	parameters = "ssss",
	description =
[[
Change the weather visual to <id> and optional <transition> for player.
!weather <id> |
!weather <id> <transition> |
]],
}

function onTrigger(player, argc, weather, updateTime, zonewide)
	-- todo: change weather
	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[weather] "
	local message = "unable to change weather"

	if player then
		weather = tonumber(weather) or 0
		updateTime = tonumber(updateTime) or 0
		zonewide = tonumber(zonewide) or 0

		if weather > 0 and weather < 82 then
			weather = weather + 8000
		end


		message = string.format("changed weather to %u ", weather)

		if zonewide ~= 0 then
			message = string.format(message.."for zone %u", player.CurrentArea.ZoneId)
		else
			message = message..player:GetName()
		end

		player.CurrentArea:ChangeWeather(weather, updateTime, player, zonewide ~= 0)
		player:SendMessage(messageId, sender, message)
	end
	print(sender..message)
end