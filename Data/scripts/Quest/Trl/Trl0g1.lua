require("Global")

--[[
Getting Started (Mother Miounne) (Trl0g1, 110141): the "Getting Started" option on Miounne.
Every player has this quest active at all times.
--]]

function onTalk(player, quest, npc, eventName)
	local choice = callClientFunction(player, "delegateEvent", player, quest, "processEventMiounneStart")

	if choice == 1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent225")
	elseif choice == 2 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent230")
	end

	player:EndEvent()
end

function IsQuestENPC(player, quest, npc)
	return npc:GetActorClassId() == 1000230
end