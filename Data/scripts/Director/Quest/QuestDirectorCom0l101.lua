require("Global")
require("QuestDuty")
require("Quest/Com/Com0l1")

--[[
Com0l1: Urianger's familiar east of Wineport. The fight is Content/Quest/QuestBattle.lua, variant Com0l101.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l101"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0l1",
		encounter = "QuestDirectorCom0l101"
	})
end

function main()
end
