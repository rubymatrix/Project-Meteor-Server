require("Global")
require("Utils")

--[[
Ability command: runs the ability on the target through the player's battle code. Each ability's
own hooks are in Command/Ability/.
--]]

local attackMagicHandlers = {

}

function onEventStarted(player, command, eventType, eventName, arg1, arg2, arg3, arg4, targetActor, arg5, arg6, arg7, arg8)
	player:Ability(command.Id, targetActor)
	player:EndEvent()
end