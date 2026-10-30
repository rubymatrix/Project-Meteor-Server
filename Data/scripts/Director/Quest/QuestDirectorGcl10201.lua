require("Global")
require("QuestDuty")
require("Quest/Gcl/Gcl102")

--[[
Gcl102: the Garleans in Mor Dhona. The fight is Content/Quest/QuestBattle.lua, variant Gcl10201.
--]]

function init()
	return "/Director/Quest/QuestDirectorGcl10201"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcl102",
		encounter = "QuestDirectorGcl10201"
	})
end

function main()
end
