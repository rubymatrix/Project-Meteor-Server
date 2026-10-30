require("Global")

--[[
Caravan adviser: chocobo-feeding advice and gysahl green sales.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local gysahlPrice = 20
	local choice = callClientFunction(player, "adviserAsk")

	if choice == 1 then
		callClientFunction(player, "adviserAdvise")
	elseif choice == 2 then
		local purchaseChoice = callClientFunction(player, "adviserSales", gysahlPrice)

		if purchaseChoice == 1 then
			callClientFunction(player, "adviserBuy")
		elseif purchaseChoice == 2 then
			callClientFunction(player, "adviserBuyNG")
		end
	elseif choice == 3 then
		callClientFunction(player, "adviserDeffault")
	end

	player:EndEvent()
end