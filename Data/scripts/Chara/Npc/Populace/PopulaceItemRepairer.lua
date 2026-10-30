require("Global")

--[[
Item repairer: menu, item picker and repair or facility confirm boxes. No repair is applied yet.
Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceItemRepairer.md.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local listIndx

	result = callClientFunction(player, "talkWelcome", player, true, 20, false)

	if result == 1 then
		local currentPage = 1
		local slotToRepair = nil

		while true do
			slot, page, listIndx = callClientFunction(player, "selectItem", nil, currentPage, 4, 2, 55, 55, 55, 55)

			if slot == nil and page ~= nil then
				currentPage = page
			else
				slotToRepair = slot
				break
			end
		end

		if slotToRepair ~= nil then
			callClientFunction(player, "confirmRepairItem", player, 100, 8032827, 0)
		end

	elseif result == 2 then
		callClientFunction(player, "confirmUseFacility", player)
	end

	callClientFunction(player, "finishTalkTurn")

	player:EndEvent()
end