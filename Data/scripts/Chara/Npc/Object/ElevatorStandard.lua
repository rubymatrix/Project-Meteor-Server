require("Global")

--[[
Lifts in Limsa Lominsa and Ul'dah: ask for a floor, play its cutscene, then warp.
--]]

local endEventAndWarp

function onEventStarted(player, npc, eventType, eventName)
	local actorClassId = npc:GetActorClassId()

	-- Limsa; Crow's Lift Level 1
	if actorClassId == 1290007 then
		local floorChoice = callClientFunction(player, "elevatorAskLimsa001", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskLimsa001", 1)
			endEventAndWarp(player, 133, -447, 40, 220, -1.574)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskLimsa001", 2)
			endEventAndWarp(player, 133, -458, 92, 175, -0.383)
		end
	-- Limsa; Crow's Lift Level 2
	elseif actorClassId == 1290008 then
		local floorChoice = callClientFunction(player, "elevatorAskLimsa002", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskLimsa002", 1)
			endEventAndWarp(player, 133, -447, 19, 220, -1.574)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskLimsa002", 2)
			endEventAndWarp(player, 133, -458, 92, 175, -0.383)
		end
	-- Limsa; Crow's Lift Level 3
	elseif actorClassId == 1290009 then
		local floorChoice = callClientFunction(player, "elevatorAskLimsa003", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskLimsa003", 1)
			endEventAndWarp(player, 133, -447, 19, 220, -1.574)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskLimsa003", 2)
			endEventAndWarp(player, 133, -447, 40, 220, -1.574)
		end
	-- Ul'dah; Wellhead Lift Level 1
	elseif actorClassId == 1090460 then
		local floorChoice = callClientFunction(player, "elevatorAskUldah001", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskUldah001", 1)
			endEventAndWarp(player, 209, -116.78, 222, 115.7, 2.85)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskUldah001", 2)
			endEventAndWarp(player, 209, -121.60, 269.8, 135.28, -0.268)
		end
	-- Ul'dah; Wellhead Lift Level 2
	elseif actorClassId == 1090461 then
		local floorChoice = callClientFunction(player, "elevatorAskUldah002", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskUldah002", 1)
			endEventAndWarp(player, 175, -116.78, 198, 115.7, -2.8911)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskUldah002", 2)
			endEventAndWarp(player, 209, -121.60, 269.8, 135.28, -0.268)
		end
	-- Ul'dah; Wellhead Lift Level 3
	elseif actorClassId == 1090462 then
		local floorChoice = callClientFunction(player, "elevatorAskUldah003", 0)
		if floorChoice == 1 then
			callClientFunction(player, "elevatorAskUldah003", 1)
			endEventAndWarp(player, 175, -116.78, 198, 115.7, -2.8911)
		elseif floorChoice == 2 then
			callClientFunction(player, "elevatorAskUldah003", 2)
			endEventAndWarp(player, 209, -116.78, 222, 115.7, 2.85)
		end
	end

end

function endEventAndWarp(player, zoneId, x, y, z, rotation)
	player:EndEvent()
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, x, y, z, rotation)
end