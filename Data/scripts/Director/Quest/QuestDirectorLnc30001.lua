require("Global")
require("QuestFlow")
require("Quest/Lnc/Lnc300")

--[[
Culture Shock (Lnc300 SEQ_030): the Ul'dahn caravan's defense in Central Shroud. Five woodsent
pterocs, then two woodsent does.
The fight is Content/Quest/QuestBattle.lua, variant Lnc30001.
--]]

function init()
	return "/Director/Quest/QuestDirectorLnc30001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Lnc300",
		content = "SimpleContentLnc30001",
		encounter = "QuestDirectorLnc30001",
		sequence = SEQ_030,
		win = finishLnc300Defense,
		fail = failLnc300Defense,
	})
end

function main()
end
