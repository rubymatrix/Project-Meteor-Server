--[[
ItemCommand Script

Command 21007 "Use Item", from the item menu or an action bar shortcut. Params: the item reference
(actorId, unknown, slot, itemPackage), then the ready-command category, then the target (self from
the item menu). Only scripted consumables use the target.
--]]

function onEventStarted(player, actor, eventType, eventName, itemReference, arg2, category, arg4, target)
	if itemReference ~= nil and itemReference.slot ~= nil then
		local useTarget = nil
		if target ~= nil and type(target) == "userdata" then
			local ok, isChara = pcall(function() return target:GetMaxHP() ~= nil end)
			if ok and isChara then useTarget = target end
		end
		player:UseItem(itemReference.itemPackage, itemReference.slot, useTarget)
	else
		player:SendGameMessage(GetWorldMaster(), 32544, 0x20, 21007)
	end
	player:EndEvent()
end
