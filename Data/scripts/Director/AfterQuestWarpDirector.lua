require("Global")

function init()
	return "/Director/AfterQuestWarpDirector"
end

function onEventStarted(player, director, eventType, eventName)
	local quest = player:GetQuestDeclaring("AFTER_WARP_NOTICE")
	if quest ~= nil then
		quest:OnNotice(player, eventName)
	else
		player:EndEvent()
	end
end

function main()
end
