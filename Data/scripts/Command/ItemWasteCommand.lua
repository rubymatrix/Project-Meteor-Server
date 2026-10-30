--[[
Discards the item in the slot the client names.
--]]

function onEventStarted(player, actor, eventType, eventName, itemReference, targetPackage, sourcePackage, arg1, arg2, unknown, arg3, arg4, arg5, type9ItemIds)
	player:GetItemPackage(itemReference.itemPackage):RemoveItemAtSlot(itemReference.slot)
	player:EndEvent()
end
