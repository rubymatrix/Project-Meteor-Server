--[[
Bazaar trades. Every bazaar entry has a reward (what the player who fills it gets) and a seek
(what the owner wants: gil or an item).
--]]

--TODO REFACTOR

function onEventStarted(player, actor, eventType, eventName, rewardItem, seekItemOrCost, seekAmount, arg1, bazaarActorId, rewardAmount, rewardItemId, nameIndex, arg2, type9ItemIds)

	local originalReward = nil
	local originalSeek = nil
	local bazaarActor = nil

	--Get the bazaar actor
	if bazaarActorId ~= nil then
		bazaarActor = player.CurrentArea:FindActorInArea(bazaarActorId)
	end

	--Abort if no actor
	if bazaarActor == nil then
		player:SendGameMessage(player, worldMaster, 25111, 0x20)
		player:EndEvent()
		return
	end

	--If seekItem is a number, we are buying an item (ExecuteBazaarBuy)
	if type(seekItemOrCost) == "number" then
		if player:GetCurrentGil() >= seekItemOrCost then
			if GetWorldManager():BazaarBuyOperation(bazaarActor, player, bazaarActor:GetItem(rewardItem), rewardAmount, seekItemOrCost) then
			else
				player:SendGameMessage(player, worldMaster, 25111, 0x20)
			end
		else
			player:SendGameMessage(player, worldMaster, 40252, 0x20)
		end
	else --Else we are fufilling a sought out item (ExecuteBazaarSell)
		local rewardItem = bazaarActor:GetItem(rewardItem)
		local seekItem = player:GetItem(seekItemOrCost)
		if rewardItem ~= nil and seekItem ~= nil then
			if GetWorldManager():BazaarSellOperation(bazaarActor, player, rewardItem, rewardAmount, seekItem, seekAmount) then
			else
				player:SendGameMessage(player, worldMaster, 25111, 0x20)
			end
		else
		end
	end

	player:EndEvent()

end