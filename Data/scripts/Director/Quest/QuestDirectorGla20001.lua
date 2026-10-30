require("Global")
require("QuestFlow")
require("Quest/Gla/Gla200")

--[[
All Bark and No Bite (Gla200 SEQ_000): Lulutsu's Coliseum bout with the Ala Mhigan challenger.
The fight is Content/Quest/QuestBattle.lua, variant Gla20001.
--]]

function init()
	return "/Director/Quest/QuestDirectorGla20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Gla200",
		content = "SimpleContentGla20001",
		encounter = "QuestDirectorGla20001",
		sequence = SEQ_000,
		win = finishGla200Bout,
		fail = failGla200Bout,
	})
end

function main()
end
