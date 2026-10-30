require("Global")
require("QuestDuty")
require("Quest/Com/Com0u6")

--[[
Com0u6: Charledore the Steadfast southwest of Camp Horizon. The fight is Content/Quest/QuestBattle.lua, variant Com0u601.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u601"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0u6",
		encounter = "QuestDirectorCom0u601"
	})
end

function main()
end
