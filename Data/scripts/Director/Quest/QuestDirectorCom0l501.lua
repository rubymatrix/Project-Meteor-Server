require("Global")
require("QuestDuty")
require("Quest/Com/Com0l5")

--[[
Com0l5: Urianger's test east of Wineport. The fight is Content/Quest/QuestBattle.lua, variant Com0l501.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l501"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0l5",
		encounter = "QuestDirectorCom0l501"
	})
end

function main()
end
