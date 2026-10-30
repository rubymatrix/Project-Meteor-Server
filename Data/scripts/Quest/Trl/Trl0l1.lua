require("Global")

--[[
Getting Started (Trl0l1, 110140): the "Getting Started" option on Baderon.
Every player has this quest active at all times.
--]]

function onTalk(player, quest, npc, eventName)
	local choice = callClientFunction(player, "delegateEvent", player, quest, "processEventBaderonStart")

	if choice == 1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent640")
	elseif choice == 2 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent650")
	end

	player:EndEvent()
end

function IsQuestENPC(player, quest, npc)
	return npc:GetActorClassId() == 1000137
end