require("Global")
require("QuestFlow")
require("Quest/Man/Man406")

--[[

QuestDirectorEventMan40601: Futures Perfect (Man406) Seq 0/5, the Hall of the First Step (content
SimpleContentMan40601). No fight: the briefing is talk through man406.lua. The area is released once the
player is out of it.

--]]

function init()
	return "/Director/Quest/QuestDirectorEventMan40601"
end

function onEventStarted(player, director, triggerName)
	local area = player.CurrentArea
	player:EndEvent()
	-- The content transfer already prints "You have entered an instance."
	player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	local quest = player:GetQuest("Man406")
	if quest ~= nil then
		quest:UpdateENPCs()
	end
	while player.CurrentArea == area do
		wait(2)
	end
	pcall(function() area:ContentFinished() end)
end

function main()
end
