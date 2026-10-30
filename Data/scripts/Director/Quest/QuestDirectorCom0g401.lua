require("Global")
require("QuestDuty")
require("Quest/Com/Com0g4")

--[[
Com0g4: the imperials northwest of the city. The fight is Content/Quest/QuestBattle.lua, variant Com0g401.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0g401"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0g4",
		encounter = "QuestDirectorCom0g401"
	})
end

function main()
end
