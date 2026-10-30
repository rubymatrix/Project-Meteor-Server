require("Global")

--[[

BgKeepout Script

Used to send a msg to the player that they cannot proceed passed this point. Invisible walls are
linked to this object.

]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	player:SendGameMessage(player, GetWorldMaster(), 60001, 0x20)
	player:EndEvent()
end
