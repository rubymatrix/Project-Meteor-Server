require("Global")

function init()
	return "/Director/OpeningDirector"
end

function onEventStarted(player, actor, eventTrigger, eventName)
	local quest

	if player:HasQuest(110001) == true then
		quest = player:GetQuest("Man0l0")
		quest:OnNotice(player)
	elseif player:HasQuest(110005) == true then
		quest = player:GetQuest("Man0g0")
		quest:OnNotice(player)
	elseif player:HasQuest(110009) == true then
		quest = player:GetQuest("Man0u0")
		quest:OnNotice(player)
	end

end

function main()
end