require("Global")
require("QuestFlow")
require("Quest/Lnc/Lnc306")

--[[
Necessary Evils (Lnc306 SEQ_010): the broker's caravan on the south road and the woodsent elemental.
The fight is Content/Quest/QuestBattle.lua, variant Lnc30601.
--]]

function init()
	return "/Director/Quest/QuestDirectorLnc30601"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Lnc306",
		content = "SimpleContentLnc30601",
		encounter = "QuestDirectorLnc30601",
		sequence = SEQ_010,
		win = finishLnc306Battle,
		fail = failLnc306Battle,
	})
end

function main()
end
