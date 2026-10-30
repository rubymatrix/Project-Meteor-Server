require("Global")

--[[

NpcLinkshellChatCommand Script

Player class will go through all quests and see if there are active msgs for one. If there was, it will
return true and that quest must end the event (if needed). Otherwise if nothing caught the event, the
event is ended here.

--]]

function onEventStarted(player, command, eventType, eventName, npcLsId)
	if player:HandleNpcLs(npcLsId) == false then
		player:EndEvent()
	end
end
