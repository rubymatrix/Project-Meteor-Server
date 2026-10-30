require("Global")
require("QuestDuty")
require("Quest/Gcl/Gcl105")

--[[
Gcl105: the wreck's Garleans. The fight is Content/Quest/QuestBattle.lua, variant Gcl10501.
The client runs this fight under Gcg103's director class; its own script keeps the outcome with Gcl105.
--]]

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcg10301"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcl105",
		encounter = "QuestDirectorGcl10501"
	})
end

function main()
end
