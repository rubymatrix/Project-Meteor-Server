require("Global")
require("QuestFlow")
require("Quest/Pgl/Pgl300")

--[[
Here There Be Pirates (Pgl300 SEQ_030): five deckhands on the Kraken's deck.
The fight is Content/Quest/QuestBattle.lua, variant Pgl30001.
--]]

function init()
	return "/Director/Quest/QuestDirectorPgl30001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Pgl300",
		content = "SimpleContentPgl30001",
		encounter = "QuestDirectorPgl30001",
		sequence = SEQ_030,
		win = finishKrakenBoarding,
		fail = failKrakenBoarding,
		reviveOnFail = true,
	})
end

function main()
end
