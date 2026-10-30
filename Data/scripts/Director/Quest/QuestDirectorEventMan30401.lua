require("Global")
require("QuestFlow")

--[[
Forever Taken (Man304 SEQ_020): the main hall after the assembly. Nothing fights here; the
companion's talk (Man304 pressMinfilia) ends the content.
--]]

function init()
	return "/Director/Quest/QuestDirectorEventMan30401"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	if waitForContentArea(player, "SimpleContentMan30401") ~= nil then
		player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	end
end

function main()
end
