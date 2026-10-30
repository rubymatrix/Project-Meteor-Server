require("Global")
require("QuestFlow")
require("Quest/Thm/Thm306")

--[[
Law and the Order (Thm306 SEQ_010): the duel with the overweening thaumaturge at the Western
Thanalan wreck site. He can't drop below 1 HP; getting him there is his yield, and the duel is won
two seconds later.
The fight is Content/Quest/QuestBattle.lua, variant Thm30601.
--]]

function init()
	return "/Director/Quest/QuestDirectorThm30601"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Thm306",
		content = "SimpleContentThm30601",
		encounter = "QuestDirectorThm30601",
		sequence = SEQ_010,
		win = finishWreckDuel,
		fail = failWreckDuel,
		reviveOnFail = true,
	})
end

function main()
end
