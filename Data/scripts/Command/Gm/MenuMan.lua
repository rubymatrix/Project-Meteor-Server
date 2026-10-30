require("Global")

properties = {
	permissions = 0,
	parameters = "d",
	description = "Spawns the menuman",
}

function onTrigger(player, argc)

	local pos = player:GetPos()
	local x = pos[0]
	local y = pos[1]
	local z = pos[2]
	local rot = pos[3]

	local actor = player.CurrentArea:SpawnActor(9114437, "menuman", x, y, z, rot, 0, 0)

	if actor == nil then
		player:SendMessage(0x20, "", "This actor class id cannot be spawned.")
	end

end