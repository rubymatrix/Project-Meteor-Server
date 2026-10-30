require("Global")
require("QuestDuty")
require("Quest/Gcg/Gcg103")

--[[
Gcg103: the Garlean war machine. The fight is Content/Quest/QuestBattle.lua, variant Gcg10301.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcg10301"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcg103",
		encounter = "QuestDirectorGcg10301"
	})
end

function main()
end
