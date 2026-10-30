require("Global")
require("QuestDuty")
require("Quest/Com/Com0l4")

--[[
Com0l4: the imperial camp in Eastern La Noscea. The fight is Content/Quest/QuestBattle.lua, variant Com0l401.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l401"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0l4",
		encounter = "QuestDirectorCom0l401"
	})
end

function main()
end
