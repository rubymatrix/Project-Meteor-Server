require("Global")

--[[
Spawns a map object at the player for each layout instance in a range, plays an animation on it
and despawns it two seconds later.
--]]

properties = {
	permissions = 0,
	parameters = "sssss",
	description =
[[

Tests a layout/region id w/ an animation string
!testmapobj <anim> <region> <layout> <maxlayout>
]],
}

function onTrigger(player, argc, animation, layoutId, instanceId, maxInstanceId)
	instanceId = tonumber(instanceId)

	if maxInstanceId ~= nil then
		maxInstanceId = tonumber(maxInstanceId)
	else
		maxInstanceId = instanceId
	end

	actorClassId = 5900001
	while instanceId <= maxInstanceId do
		if actorClassId == nil then
			player:SendMessage(0x20, "", "No actor class id provided.")
			return
		end

		local pos = player:GetPos()
		local x = pos[0]
		local y = pos[1]
		local z = pos[2]
		local zone = pos[4]

		actorClassId = tonumber(actorClassId)

		if actorClassId ~= nil then
			zone = player.CurrentArea
			actor = zone:SpawnActor(actorClassId, "mapobj", pos[0], pos[1], pos[2], tonumber(layoutId), tonumber(instanceId))

			 print("test")
			wait(2)
			actor:PlayMapObjAnimation(player, animation)
			zone:DespawnActor("mapobj")
			wait(0.5)
			player:SendMessage(0x20, "", "Playing animation for instance: " .. instanceId)
		end
		instanceId = instanceId + 1
	end
end
--!testmapobj 5900001 421 2810 2820

--dun4 (0x19e) - Copperbell Mines
--dun1 - Mun Tuy
--dun2 - Tam Tara
--debug:_getAllCharacter("MapObjStandard")[1]


--Ferry (Thanalan, Z=-130): 5145, 252
--Ferry (La Noscea, Z=+130): 5144, 201