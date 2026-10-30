require("Global")
require("QuestDuty")
require("Quest/Com/Com0u4")

--[[
Com0u4: the Hellhounds by the Golden Bazaar. The fight is Content/Quest/QuestBattle.lua, variant Com0u401.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u401"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0u4",
		encounter = "QuestDirectorCom0u401"
	})
end

function main()
end
