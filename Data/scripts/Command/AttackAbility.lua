require("Global")
require("Utils")

--[[

AttackWeaponSkill Script

Finds the correct weaponskill subscript to fire when a weaponskill actor is activated.

--]]

local attackMagicHandlers = {

}

function onEventStarted(player, command, eventType, eventName, arg1, arg2, arg3, arg4, targetActor, arg5, arg6, arg7, arg8)
	player.Ability(command.Id, targetActor)
	player:EndEvent()

end