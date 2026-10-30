require("Global")
require("QuestDuty")
require("Quest/Gcg/Gcg102")

--[[
Gcg102: the Garleans at the Toro-Moy Battlewarrens. The fight is Content/Quest/QuestBattle.lua, variant Gcg10201.
--]]

function init()
	return "/Director/Quest/QuestDirectorGcg10201"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Gcg102",
		encounter = "QuestDirectorGcg10201"
	})
end

function main()
end
