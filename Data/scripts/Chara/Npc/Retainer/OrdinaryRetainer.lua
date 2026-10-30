require("Global")
require("Retainer")

--[[
A summoned retainer: item trade, bazaar, mannequin and dismissal menus.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, retainer, triggerName)
	local choice

	while true do
		choice = callClientFunction(player, "eventTalkRetainerMenu", 1)
		if choice == 1 then
			doItemTrade(player, retainer)
		elseif choice == 2 then
			doBazaar(player, retainer)
		elseif choice == 7 then
			callClientFunction(player, "eventTalkRetainerMannequin", 0)
		elseif choice == 5 then
			player:DespawnMyRetainer()
		else
			break
		end
	end

	player:EndEvent()

end
