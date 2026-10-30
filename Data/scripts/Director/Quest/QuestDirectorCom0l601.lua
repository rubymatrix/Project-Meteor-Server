require("Global")
require("QuestDuty")
require("Quest/Com/Com0l6")

--[[
Com0l6: the imperials at the ceruleum site. The fight is Content/Quest/QuestBattle.lua, variant Com0l601.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l601"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0l6",
		encounter = "QuestDirectorCom0l601"
	})
end

function main()
end
