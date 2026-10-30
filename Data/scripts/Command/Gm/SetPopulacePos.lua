require("Global")

properties = {
	permissions = 0,
	parameters = "sffff",
	description = "Moves an actor into a new position instantly",
}

function onTrigger(player, argc, name, posX, posY, posZ, rotation)

	local actor

	if name == nil then
		player:SendMessage(0x20, "", "No name provided.")
		return
	end

	local pos = player:GetPos()
	local x = posX or pos[0]
	local y = posY or pos[1]
	local z = posZ or pos[2]
	local rot = rotation or pos[3]

	actor = player.CurrentArea:FindActorInZoneByUniqueID(name)
	if actor ~= nil then
		actor:SetPos(x,y,z,rot,true, player)
		player:SendMessage(0x20, "", string.format("Moved %s @ %f, %f, %f, %f", name, x, y, z, rot))
	else
		player:SendMessage(0x20, "", string.format("Could not find %s.", name))
	end

end