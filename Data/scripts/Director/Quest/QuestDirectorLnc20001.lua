require("Global")
require("QuestFlow")
require("Quest/Lnc/Lnc200")

--[[
A Wailing Welcome (Lnc200 SEQ_010): J'moldva's ranging at Lifemend Stump, four orchard chigoes.
The fight is Content/Quest/QuestBattle.lua, variant Lnc20001.
--]]

function init()
	return "/Director/Quest/QuestDirectorLnc20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Lnc200",
		content = "SimpleContentLnc20001",
		encounter = "QuestDirectorLnc20001",
		sequence = SEQ_010,
		win = finishLnc200Ranging,
		fail = failLnc200Ranging,
	})
end

function main()
end
