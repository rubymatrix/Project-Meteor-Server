require("Global")

--[[
Notorious monster reward NPC. Only opens the menu; nothing is exchanged yet.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	callClientFunction(player, "eventTalkStep0", player, 0)

	player:EndEvent()
end