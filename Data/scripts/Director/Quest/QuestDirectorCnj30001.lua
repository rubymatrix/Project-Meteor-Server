require("Global")
require("QuestFlow")
require("Quest/Cnj/Cnj300")

--[[
Good Knight, Sweet Dreams (Cnj300 SEQ_010): six aspected elementals at Amberscale Rock in one wave,
while Brother Morys looks on.
The fight is Content/Quest/QuestBattle.lua, variant Cnj30001.
--]]

function init()
	return "/Director/Quest/QuestDirectorCnj30001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Cnj300",
		content = "SimpleContentCnj30001",
		encounter = "QuestDirectorCnj30001",
		sequence = SEQ_010,
		win = finishElementals,
		fail = failElementals,
	})
end

function main()
end
