require("Global")
require("Aetheryte")
require("Utils")

--[[

GuildleveWarpPoint Script

Functions:

eventGuildleveReward(glId, completionTimeSec, completeReward, difficultyBonus, faction, gil???, factionBonus, RewardId1, RewardAmount1, RewardId2, RewardAmount2, difficulty) - Open Reward Dialog
eventTalkGuildleveWarp(returnAetheryteID1, returnAetheryte2) - Opens choice menu
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local randoPos
	local currentGlDirector = player:GetGuildleveDirector()
	local glData = currentGlDirector.guildleveData

	callClientFunction(player, "eventGuildleveReward", currentGlDirector.guildleveId, currentGlDirector.completionTime, 24, 24, 0, 0, 0, 0, 0, 0, 0, currentGlDirector.selectedDifficulty)

	local choice = callClientFunction(player, "eventTalkGuildleveWarp", glData.aetheryte, 0)

	if choice == 3 then
		local destination = aetheryteTeleportPositions[glData.aetheryte]
		if destination ~= nil then
			randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
			rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
			GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
			currentGlDirector:EndDirector()
		end
	elseif choice == 4 then
		currentGlDirector:EndDirector()
	end

	player:EndEvent()
end

--50023: GL COMPLETE!
--50132: You earn faction credits from X