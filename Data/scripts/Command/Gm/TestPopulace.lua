require("Global")

properties = {
	permissions = 0,
	parameters = "dsdffff",
	description = "Spawns an actor given the actorClassId",
}

function onTrigger(player, argc, actorClassId, name, motionPack, posX, posY, posZ, rotation)

	local actor

	if actorClassId == nil then
		player:SendMessage(0x20, "", "No actor class id provided.")
		return
	end

	if motionPack == nil then
		motionPack = 0
	end

	local actorClassId = tonumber(actorClassId)
	local pos = player:GetPos()
	local x = x or pos[0]
	local y = y or pos[1]
	local z = z or pos[2]
	local rot = rotation or pos[3]

	if actorClassId ~= nil and name ~= nil then

		actor = player.CurrentArea:SpawnActor(1000001, name, x, y, z, rot, 0, motionPack)
		actor:ChangeNpcAppearance(actorClassId)
		player:SendMessage(0x20, "", string.format("Spawned %d @ %f, %f, %f, %f", actorClassId, x, y, z, rot))
	end

	if actor == nil then
		player:SendMessage(0x20, "", "This actor class id cannot be spawned.")
	end

end