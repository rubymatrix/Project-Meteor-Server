require("Global")

properties = {
	permissions = 0,
	parameters = "d",
	description = "Simulates killing a bnpc. Used for quest testing.",
}

function onTrigger(player, argc, actorClassId)
	if argc == 1 then
		player:HandleBNpcKill(actorClassId)
		player:SendMessage(0x20, "", "Simulating BNpc kill for actor class id: " .. tostring(actorClassId))
	else
		player:SendMessage(0x20, "", "No actor class id provided.")
	end
end