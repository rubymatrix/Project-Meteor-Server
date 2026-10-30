require("Global")

--[[
Parley (negotiation). Client functions: Data/Docs/Scripts/Command/NegotiationCommand.md.
--]]

-- Parley (command 29497) on a target belongs to the quest that owns it: that quest's onParley plays
-- it and ends the event. The client offers Parley only on npcs whose class allows it.
local PARLEY_RANGE = 15.0
local TEXT_TOO_FAR_AWAY = 25081
local TEXT_UNABLE_TO_PARLEY = 40428

local function resolveTarget(player, targetActorId)
	local actorId = tonumber(targetActorId)
	if actorId == nil or actorId == 0 then
		actorId = player.currentTarget
	end
	if actorId == nil or actorId == 0 then
		return nil
	end
	return player:GetActorInInstance(actorId)
end

function onEventStarted(player, commandactor, eventType, eventName, arg1, arg2, arg3, arg4, targetActorId)
	local target = resolveTarget(player, targetActorId)
	if target == nil then
		player:EndEvent()
		return
	end

	local ok, quests = pcall(function() return toLuaTable(player:GetQuestsForNpc(target)) end)
	if not ok or #quests == 0 then
		player:SendGameMessage(GetWorldMaster(), TEXT_UNABLE_TO_PARLEY, 0x20, 0, 0, target)
		player:EndEvent()
		return
	end

	local dx, dz = player.positionX - target.positionX, player.positionZ - target.positionZ
	if dx * dx + dz * dz > PARLEY_RANGE * PARLEY_RANGE then
		player:SendGameMessage(GetWorldMaster(), TEXT_TOO_FAR_AWAY, 0x20)
		player:EndEvent()
		return
	end

	quests[1]:OnParley(player, target)
end
