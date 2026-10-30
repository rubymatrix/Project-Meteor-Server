require("Global")

--[[
Caravan guide, who leads the chocobos in Caravan Security. Only the offer dialog is wired up, with fixed
area values. Client functions and lines: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceCaravanGuide.md.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local areaName = 1
	local areaName2 = 3
	local playerGc = 1
	local cargo = 9
	local killCount = 50
	callClientFunction(player, "caravanGuardOffer", areaName, areaName2, playerGc)


	player:EndEvent()
end