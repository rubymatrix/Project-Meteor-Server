require("Global")
require("QuestFlow")
require("Quest/Pgl/Pgl306")

--[[
Two Sides to Every Chip (Pgl306 SEQ_040): the Silver Bazaar ambush. Hurrey fights beside the player
against two Ossuary almstakers.
The fight is Content/Quest/QuestBattle.lua, variant Pgl30601.
--]]

function init()
	return "/Director/Quest/QuestDirectorPgl30601"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Pgl306",
		content = "SimpleContentPgl30601",
		encounter = "QuestDirectorPgl30601",
		sequence = SEQ_040,
		win = finishBazaarAmbush,
		fail = failBazaarAmbush,
		reviveOnFail = true,
	})
end

function main()
end
