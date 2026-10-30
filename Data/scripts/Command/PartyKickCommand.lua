--[[
Ousting a party member, and the errors when that fails. Text ids:
Data/Docs/Scripts/Command/PartyKickCommand.md.
--]]

function onEventStarted(player, actor, eventType, eventName, name, arg2, arg3, arg4, actorId)
	worldMaster = GetWorldMaster()

	if player:IsPartyLeader() then
		if name == nil then
			player:PartyOustPlayer(actorId)
		else
			player:PartyOustPlayer(name)
		end
	else
		player:SendGameMessage(player, worldMaster, 30540, 0x20)
	end

	player:EndEvent()
end