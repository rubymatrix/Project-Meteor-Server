require("Global")

--[[
Bounty presenter. Only the lower-level line is wired.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	callClientFunction(player, "eventLowerLevel", player)
	player:EndEvent()

end