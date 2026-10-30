require("Global")

--[[
Tells the player they can't go past this point. Invisible walls are linked to this object.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	player:SendGameMessage(player, GetWorldMaster(), 60001, 0x20)
	player:EndEvent()
end
