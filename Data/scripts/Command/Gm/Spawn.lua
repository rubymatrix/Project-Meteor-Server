require("Global")

properties = {
	permissions = 0,
	parameters = "d",
	description = "Spawns a actor",
}

function onTrigger(player, argc, actorClassId, width, height)

	if actorClassId == nil then
		player:SendMessage(0x20, "", "No actor class id provided.")
		return
	end

	local pos = player:GetPos()
	local x = pos[0]
	local y = pos[1]
	local z = pos[2]
	local rot = pos[3]
	local zone = pos[4]

	actorClassId = tonumber(actorClassId)

	if actorClassId ~= nil then
		local w = tonumber(width) or 0
		local h = tonumber(height) or 0
		printf("%f %f %f", x, y, z)
		--local x, y, z = player.GetPos();
		for i = 0, w do
			for j = 0, h do
				actor = player.CurrentArea:SpawnActor(actorClassId, "test", x + (i - (w / 2) * 3), y, z + (j - (h / 2) * 3), rot)
				actor:ChangeNpcAppearance(1001149)
			end
		end
	end

	if actor == nil then
		player:SendMessage(0x20, "", "This actor class id cannot be spawned.")
	end

end