--[[
Retainer item trade and bazaar menus, shared by the retainer bell and retainer NPCs.
Retainer say codes: Data/Docs/Scripts/Retainer.md.
--]]

function doItemTrade(player, retainer)
	callClientFunction(player, "eventTalkRetainerItemTrade", 1)

	while true do
		resultCode, item, un1, quantity, itemId, quality = callClientFunction(player, "eventTalkRetainerItemTrade", 2)

		player:SendMessage(0x20, "", "" .. tostring(resultCode))
		player:SendMessage(0x20, "", "" .. tostring(un1))
		player:SendMessage(0x20, "", "" .. tostring(quantity))
		player:SendMessage(0x20, "", "" .. tostring(itemId))
		player:SendMessage(0x20, "", "" .. tostring(quality))

		if resultCode == 31 then
			retainer:GetItemPackage(item.itemPackage):RemoveItemAtSlot(item.slot, quantity)
			retainer:GetItemPackage(item.itemPackage):SendUpdate(player)
			player:GetItemPackage(item.itemPackage):AddItem(itemId, quantity, quality)
		elseif resultCode == 32 then
			player:GetItemPackage(item.itemPackage):RemoveItemAtSlot(item.slot, quantity)
			retainer:GetItemPackage(item.itemPackage):AddItem(itemId, quantity, quality)
			retainer:GetItemPackage(item.itemPackage):SendUpdate(player)
		end

		callClientFunction(player, "eventReturnResult", resultCode, false)

		if resultCode == 100 then
			break
		end
	end

	callClientFunction(player, "eventTalkRetainerItemTrade", 3)
end

function doBazaar(player, retainer)
	callClientFunction(player, "eventTalkRetainerItemList", 1)
	callClientFunction(player, "eventTalkRetainerItemList", 2)
	callClientFunction(player, "eventTalkRetainerItemList", 3)
end