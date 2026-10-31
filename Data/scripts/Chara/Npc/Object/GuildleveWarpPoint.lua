require("Global")
require("Aetheryte")
require("Utils")

--[[
Aetherial node a completed battle leve leaves at its last objective: shows the reward window, then
offers the return to the leve's aetheryte. GuildleveDirector:ClaimReward pays the gil and item once;
a player who never touches the node collects them later at any aetheryte. Client functions:
Data/Docs/Scripts/Chara/Npc/Object/GuildleveWarpPoint.md.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local director = player:GetGuildleveDirector()
	if director == nil then
		player:EndEvent()
		return
	end
	local glData = director.guildleveData

	local r = director:ClaimReward(player)
	if r ~= nil then
		callClientFunction(player, "eventGuildleveReward", r.glId, r.clearSeconds, r.missionBonus, r.difficultyBonus,
			r.faction, r.factionBonus, r.factionCredit, 1000001, r.gil, r.item2, r.qty2, r.stars)
	end

	local choice = callClientFunction(player, "eventTalkGuildleveWarp", glData.aetheryte, 0)

	-- The zone change removes every actor on the client, so the node's EndEvent has to go first.
	player:EndEvent()

	if choice == 3 then
		local destination = aetheryteTeleportPositions[glData.aetheryte]
		if destination ~= nil then
			local randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
			local rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
			GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
			player:AddHP(player:GetMaxHP())
			player:AddMP(player:GetMaxMP())
			player:SendGameMessage(GetWorldMaster(), 50028, 0x20) -- HP and MP are restored
			player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- no longer bound by duty
		end
	end
end
