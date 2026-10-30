require("Global")

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, eventType, eventName)
	if eventName == "caution" then
		worldMaster = GetWorldMaster()
		player:SendGameMessage(player, worldMaster, 34109, 0x20)
	elseif eventName == "exit" then
		GetWorldManager():DoPlayerMoveInZone(player, 356.09, 3.74, -701.62, -1.4)
	end
	player:EndEvent()
end