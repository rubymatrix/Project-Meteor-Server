require("Global")

--[[
Branch vendor: greets, opens the item search, then ends the talk.
eventSearchItemAsk(nil, stopSearchingItemId) is the client's search menu.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	callClientFunction(player, "eventTalkWelcome", player)
	callClientFunction(player, "eventSearchItemAsk", nil, 0)
	callClientFunction(player, "eventTalkStepBreak", player)
	player:EndEvent()

end