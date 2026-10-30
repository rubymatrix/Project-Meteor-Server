require("Global")
require("QuestDuty")
require("Quest/Com/Com0g6")

--[[
Com0g6: the beasts west of Nine Ivies. The fight is Content/Quest/QuestBattle.lua, variant Com0g601.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0g601"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0g6",
		encounter = "QuestDirectorCom0g601"
	})
end

function main()
end
