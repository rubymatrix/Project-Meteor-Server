--[[
Buying and selling for shop NPCs: moves the item and the currency, then prints the shop message.
--]]

function purchaseItem(player, location, itemId, quantity, quality, price, currency)

	local worldMaster = GetWorldMaster()
	local invCheck = -1

	if player:GetItemPackage(INVENTORY_CURRENCY):HasItem(currency, price) then
		invCheck = player:GetItemPackage(location):AddItem(itemId, quantity, quality)

		if invCheck == INV_ERROR_FULL then
			-- Your inventory is full.
			player:SendGameMessage(player, worldMaster, 60022, MESSAGE_TYPE_SYSTEM)
		elseif invCheck == INV_ERROR_ALREADY_HAS_UNIQUE then
			-- "You cannot have more than one ... in your possession at any given time."
			player:SendGameMessage(player, worldMaster, 40279, MESSAGE_TYPE_SYSTEM, itemId, quality)
		elseif invCheck == INV_ERROR_SYSTEM_ERROR then
			player:SendMessage(0x20, "", "[DEBUG] Server Error on adding item.")
		elseif invCheck == INV_ERROR_SUCCESS then
			player:GetItemPackage(INVENTORY_CURRENCY):RemoveItem(currency, price)

			if currency == 1000001 then  -- Gil
				-- "You purchase ... for ... gil."
				player:SendGameMessage(player, worldMaster, 25061, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, price)

			elseif currency == 1000201 or currency == 1000202 or currency == 1000203 then  -- Grand Company seals
				-- "You exchange ... seals for ..."
				player:SendGameMessage(player, worldMaster, 25275, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, price, player.gcCurrent)

			elseif currency >= 1000101 and currency <= 1000123 then -- Guild marks
				-- "You trade ... for ..."
				player:SendGameMessage(player, GetWorldMaster(), 25071, MESSAGE_TYPE_SYSTEM, currency, 1, itemId, 1, price, quantity)
			end
		end
	else
		-- You do not have enough gil.  (Should never see this)
		player:SendGameMessage(player, worldMaster, 25065, MESSAGE_TYPE_SYSTEM)
	end
	return
end


function sellItem(player, itemId, quantity, quality, itemPrice, slot, currency)
	local worldMaster = GetWorldMaster()
	local cost = quantity * itemPrice

	player:GetItemPackage(INVENTORY_CURRENCY):AddItem(currency, cost)
	player:GetItemPackage(INVENTORY_NORMAL):RemoveItemAtSlot(slot, quantity)
	-- "You sell ... for ... gil."
	player:SendGameMessage(player, worldMaster, 25075, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, cost)
end