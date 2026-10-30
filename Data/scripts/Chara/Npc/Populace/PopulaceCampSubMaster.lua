require("Global")

--[[
Camp facility NPC: welcome talk and the use-facility confirmation. Nothing is charged or granted yet.
Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceCampSubMaster.md.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local confirmed

	local choice = callClientFunction(player, "talkWelcome", player, 1, false)

	if choice == 1 then
		confirmed = callClientFunction(player, "confirmUseFacility", player, 1)
	end

	callClientFunction(player, "finishTalkTurn")

	player:EndEvent()

end