require("Global")

--[[
Achievement NPC. Only the default talk is wired up; the client also has eventNoGC, eventUnlock(sheetId)
and eventReward for unlocks.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	callClientFunction(player, "defTalk")

	player:EndEvent()
end