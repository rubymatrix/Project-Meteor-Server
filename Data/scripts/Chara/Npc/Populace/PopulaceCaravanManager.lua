require("Global")

--[[
Caravan sign-up NPC. Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceCaravanManager.md.
--]]

function init(npc)
	return false, false, 0, 0
end

-- Serpent Sergeant Marquaile at Camp Tranquil starts a caravan escort
-- (Content/CaravanGuard/CaravanGuardTranquil.lua) for the player who signs up.
function onEventStarted(player, npc, triggerName)
	local GC = 3
	local playerGc = 1
	local areaName = 0
	local level = 25
	local playerCount = 8
	local difficulty = 41
	local hasRoomForGcSeals = false
	local areaName1, areaName2 = 1, 3

	local choice = callClientFunction(player, "caravanGuardEntry", GC, hasRoomForGcSeals, areaName, difficulty, playerGc, playerCount, level)
	if choice == 1 then
		local caravan = GetContentFor(player)
		if caravan == nil then
			caravan = StartContent("CaravanGuardTranquil", "", player.CurrentArea, player, { level = level })
		end
		if caravan ~= nil then
			callClientFunction(player, "caravanGuardJoinOK", areaName1, areaName2, playerGc)
		end
	end
	player:EndEvent()
end
