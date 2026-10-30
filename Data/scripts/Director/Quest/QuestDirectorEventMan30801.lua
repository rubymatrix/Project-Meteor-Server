require("Global")
require("QuestFlow")
require("Quest/Man/Man308")

--[[
Lord Errant (Man308) SEQ_010, the Paglth'an cell (content SimpleContentMan30802, Southern
Thanalan 174). No fight: the prisoners, the Path companion and the cave exit are talked to and
pushed through Man308.lua.
--]]

function init()
	return "/Director/Quest/QuestDirectorEventMan30801"
end

function onEventStarted(player, director, triggerName)
	local area = player.CurrentArea
	player:EndEvent()
	-- The content transfer already prints "You have entered an instance."
	player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	local quest = player:GetQuest("Man308")
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
