require("Global")
require("Retainer")

--[[
Retainer bell: summons the chosen retainer and runs its menu until the player leaves.
Client functions: Data/Docs/Scripts/Chara/Npc/Object/RetainerFurniture.md.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local choice
	local retainerNumber = callClientFunction(player, "eventPushStepOpenRetainerMenu")

	if retainerNumber == nil or retainerNumber == 0 then
		player:EndEvent()
		return
	end

	callClientFunction(player, "eventRingBell")
	local retainer = player:SpawnMyRetainer(npc, retainerNumber)

	while true do
		choice = callClientFunction(player, "eventTalkRetainerMenu", false, true)
		if choice == 1 then
			doItemTrade(player, retainer)
		elseif choice == 2 then
			doBazaar(player, retainer)
		elseif choice == 7 then
			callClientFunction(player, "eventTalkRetainerMannequin", 0)
		elseif choice == 8 then
			callClientFunction(player, "eventTalkSelectBazaarStreet", 20)
		else
			break
		end
	end

	player:DespawnMyRetainer()
	player:EndEvent()
end
