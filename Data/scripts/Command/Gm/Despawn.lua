require("Global")

properties = {
	permissions = 0,
	parameters = "d",
	description = "Spawns a actor",
}

function onTrigger(player, argc, actorName)

	if actorName ~= nil then
		actor = player.CurrentArea:DespawnActor(actorName)
	end

end