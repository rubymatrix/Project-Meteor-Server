require("Global")

--[[
Mounting and dismounting the chocobo and the goobbue.
--]]

function onEventStarted(player, actor, eventType, eventName, isGoobbue)
	if player:GetState() == 0 then

		worldMaster = GetWorldMaster()

		if isGoobbue ~= true then
			player:ChangeMusic(83, MUSIC_FADEIN)
			player:SendGameMessage(player, worldMaster, 26001, 0x20)
			player:SetMountState(1)
		else
			player:ChangeMusic(98, MUSIC_FADEIN)
			player:SendGameMessage(player, worldMaster, 26019, 0x20)
			player:SetMountState(2)
		end

		player:ChangeSpeed(0.0, 3.6, 9.0, 9.0)
		player:ChangeState(15)
	else
		player:ChangeMusic(player.CurrentArea.bgmDay, MUSIC_FADEIN)

		worldMaster = GetWorldMaster()

		if player.rentalExpireTime ~= 0 then
			player:SendGameMessage(player, worldMaster, 26004, 0x20) --You dismount.
		else
			if player:GetMountState() == 1 then
				player:SendGameMessage(player, worldMaster, 26003, 0x20) --You dismount X.
			else
				player:SendGameMessage(player, worldMaster, 26021, 0x20) --You dismount your Gobbue.
			end
		end

		player:SetMountState(0)
		player:ChangeSpeed(0.0, 2.0, 5.0, 5.0)
		player:ChangeState(0)
	end
	player:EndEvent()
end