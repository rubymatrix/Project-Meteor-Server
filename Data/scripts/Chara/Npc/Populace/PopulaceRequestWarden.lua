require("Global")

--[[
Request warden: plays one talk step (eventTalkStep14) and ends. The client's init args are
speechType and townType.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	result = callClientFunction(player, "eventTalkStep14")

	player:EndEvent()
end