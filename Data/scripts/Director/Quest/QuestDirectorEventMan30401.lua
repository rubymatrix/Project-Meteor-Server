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
	waitForContentArea(player, "SimpleContentMan30401")
end

function main()
end
