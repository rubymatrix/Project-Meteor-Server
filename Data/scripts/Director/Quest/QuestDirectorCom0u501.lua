require("Global")
require("QuestDuty")
require("Quest/Com/Com0u5")

--[[
Com0u5: the pirates at the ferry docks. The fight is Content/Quest/QuestBattle.lua, variant Com0u501.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u501"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0u5",
		encounter = "QuestDirectorCom0u501"
	})
end

function main()
end
