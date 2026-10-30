require("Global")

--[[
Camp master: asks which aetheryte to favour. defTalk(player, fav1, fav2, fav3, playerLevel, ?) is
its only client function; with fav1 == 0 it doesn't ask which favourite to drop.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	local favLocation = callClientFunction(player, "defTalk", player, 0, 1280004, 1280005)

	--if (hasThree) then
		--Remove chosen
	--end

	player:EndEvent()
end