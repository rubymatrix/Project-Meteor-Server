require("Global")

--[[

PopulaceCaravanManager Script

Functions:

caravanGuardEntry(areaGC, hasRoomForGCSeals, areaName, difficulty, playerGC, playerCountRequired, levelRequired) 
       - Dialog for signing up for caravan. areaGC(1-3) & areaName(0 or 3) added together to get location name.  
       - If difficulty => 40 on areaGC 1-3 & areaName 0, NPC mentions it's be a tougher trip
       
caravanGuardQuestion(areaName1, areaName2, escortMax, isSameGC?, playerGC?) - Ask about the caravan escort
caravanGuardJoinOK(areaName1, areaName2, playerGC)   - Dialog for successfully joining the caravan
caravanGuardJoinNG(nil, maxEscorts, playerGC)        - Dialog dictating how many escorts total filled the run.  
caravanGuardAmple(nil, playerGC, playerGC)           - Dialog for caravan escort being full.
caravanGuardOther(npcGC)                             - Dialog where NPC mentions you're not part of the given Grand Company parameter
caravanGuardSigh()                                   - NPC does a shrug animation
caravanGuardHuh()                                    - NPC does /huh
caravanGuardCancel(nil, playerGC)                    - Dialog for canceling caravan escort. 


Notes:
Some NPC dialog address you differently if your GC rank is Chief Sergeant (id 27) or higher, but only in non-English languages.

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
