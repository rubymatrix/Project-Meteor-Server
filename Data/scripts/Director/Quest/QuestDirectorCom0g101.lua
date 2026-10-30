require("Global")
require("QuestDuty")
require("Quest/Com/Com0g1")

--[[
Com0g1: Urianger's familiar southwest of Quarrymill. The fight is Content/Quest/QuestBattle.lua, variant Com0g101.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0g101"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0g1",
		encounter = "QuestDirectorCom0g101"
	})
end

function main()
end
