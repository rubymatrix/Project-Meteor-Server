require("Global")
require("QuestFlow")
require("Quest/Gla/Gla306")

--[[
Thrill of the Fight (Gla306 SEQ_024): the Echo bout with the Ala Mhigan challenger.
The fight is Content/Quest/QuestBattle.lua, variant Gla30602.
--]]

function init()
	return "/Director/Quest/QuestDirectorGla30602"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Gla306",
		content = "SimpleContentGla30602",
		encounter = "QuestDirectorGla30602",
		sequence = SEQ_024,
		win = finishGla306Challenger,
		fail = failGla306Bout,
	})
end

function main()
end
