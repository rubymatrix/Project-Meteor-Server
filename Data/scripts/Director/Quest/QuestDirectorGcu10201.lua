require("Global")
require("QuestDuty")
require("Quest/Gcu/Gcu102")

--[[
Gcu102: the Garleans in the cave by Camp Black Brush. The fight is Content/Quest/QuestBattle.lua, variant Gcu10201.
--]]

function init()
	return "/Director/Quest/QuestDirectorGcu10201"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcu102",
		encounter = "QuestDirectorGcu10201"
	})
end

function main()
end
