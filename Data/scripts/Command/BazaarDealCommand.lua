require("Global")

--[[
Puts an item up in the player's bazaar: for gil, or in exchange for another item.
--]]

function onEventStarted(player, actor, eventType, eventName, rewardItem, seekItem, bazaarMode, arg1, bazaarActor, rewardAmount, seekAmount, arg2, arg3, type9ItemIds)

	local rewarding = nil
	local seeking = nil

	--Handle special case for offering an item.
	if seekItem == nil then
		rewarding = player:GetItemPackage(rewardItem.offerPackageId):GetItemAtSlot(rewardItem.offerSlot)
		seeking = player:GetItemPackage(rewardItem.seekPackageId):GetItemAtSlot(rewardItem.seekSlot)
	end

	--Handle Reward
	if rewarding == nil then
		if type(rewardItem) == "number" then
			rewarding = player:GetItemPackage(INVENTORY_CURRENCY):GetItemByCatelogId(rewardItem)
		else
			rewarding = player:GetItem(rewardItem)
		end
	end

	--Handle Seek
	if seeking == nil then
		if type(seekItem) == "number" then
			seeking = player:GetItemPackage(INVENTORY_CURRENCY):GetItemByCatelogId(seekItem)
		else
			seeking = player:GetItem(seekItem)
		end
	end

	result = GetWorldManager():AddToBazaar(player, rewarding, seeking, rewardAmount, seekAmount, bazaarMode)



	player:EndEvent()

end