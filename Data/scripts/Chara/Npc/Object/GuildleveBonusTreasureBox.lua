require("Global")

--[[
Bonus treasure box a battle leve may place in its area. The client class has no UI of its own, so
opening it is talkDefault -> GuildleveDirector:OnBonusBox pays the reward -> EndEvent.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local director = player:GetGuildleveDirector()
	if director ~= nil then
		director:OnBonusBox(player, npc)
	end
	player:EndEvent()
end
