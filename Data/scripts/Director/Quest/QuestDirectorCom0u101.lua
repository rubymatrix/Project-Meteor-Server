require("Global")
require("QuestDuty")
require("Quest/Com/Com0u1")

--[[
Com0u1: Urianger's familiar southeast of the ferry docks. The fight is Content/Quest/QuestBattle.lua, variant Com0u101.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u101"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0u1",
		encounter = "QuestDirectorCom0u101"
	})
end

function main()
end
