require("Global")
require("QuestDuty")
require("Quest/Gcl/Gcl103")

--[[
Gcl103: the Garlean war machine in Upper La Noscea. The fight is Content/Quest/QuestBattle.lua, variant Gcl10301.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcl10301"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcl103",
		encounter = "QuestDirectorGcl10301"
	})
end

function main()
end
