require("Global")

--[[
The Path companion classes: the companion that walks with the player through the Path of the Twelve
duties. Talk, push, emote and notice go to the held quest that owns the class; with none the event
just closes. No init: PopulaceStandard's would change how the companion is instantiated.
--]]

function onEventStarted(player, npc, eventType, eventName)
	local quest = arrayToTable(player:GetQuestsForNpcEvent(npc, eventType))[1]
	if quest == nil then
		player:EndEvent()
		return
	end

	if eventType == ETYPE_TALK then
		quest:OnTalk(player, npc)
	elseif eventType == ETYPE_PUSH then
		quest:OnPush(player, npc, eventName)
	elseif eventType == ETYPE_EMOTE then
		quest:OnEmote(player, npc, eventName)
	elseif eventType == ETYPE_NOTICE then
		quest:OnNotice(player, eventName)
	else
		player:EndEvent()
	end
end
