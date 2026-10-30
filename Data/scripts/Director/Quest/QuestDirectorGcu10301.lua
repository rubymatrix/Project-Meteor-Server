require("Global")
require("QuestDuty")
require("Quest/Gcu/Gcu103")

--[[
Gcu103: the juggernaut west of Camp Horizon. The fight is Content/Quest/QuestBattle.lua, variant Gcu10301.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcu10301"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcu103",
		encounter = "QuestDirectorGcu10301"
	})
end

function main()
end
