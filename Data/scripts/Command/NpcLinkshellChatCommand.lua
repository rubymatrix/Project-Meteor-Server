require("Global")

--[[
Reads an NPC linkshell message. The quest that owns the message ends the event itself; when no quest
claims it, the event ends here.
--]]

function onEventStarted(player, command, eventType, eventName, npcLsId)
	if player:HandleNpcLs(npcLsId) == false then
		player:EndEvent()
	end
end
