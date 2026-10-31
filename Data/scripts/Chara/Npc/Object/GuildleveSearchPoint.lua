require("Global")

--[[
Ground light of Necrologos (Orb) and Hunt battle leves. The client class has no UI of its own, so a
search is talkDefault -> GuildleveDirector:OnSearchPoint sends the result -> EndEvent.
--]]

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local director = player:GetGuildleveDirector()
	if director ~= nil then
		director:OnSearchPoint(player, npc)
	end
	player:EndEvent()
end
