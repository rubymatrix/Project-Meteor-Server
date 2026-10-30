require("Global")

--[[
Debug NPC: opens the client's debug menu.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	callClientFunction(player, "debugMenuEvent", player)
	player:EndEvent()
end

