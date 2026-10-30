require("Global")
require("QuestFlow")
require("Quest/Gla/Gla306")

--[[
Thrill of the Fight (Gla306 SEQ_005): the Coliseum bout with the Ala Mhigan bladedancer.
The fight is Content/Quest/QuestBattle.lua, variant Gla30601.
--]]

function init()
	return "/Director/Quest/QuestDirectorGla30601"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Gla306",
		content = "SimpleContentGla30601",
		encounter = "QuestDirectorGla30601",
		sequence = SEQ_005,
		win = finishGla306Bladedancer,
		fail = failGla306Bout,
	})
end

function main()
end
