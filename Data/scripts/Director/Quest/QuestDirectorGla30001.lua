require("Global")
require("QuestFlow")
require("Quest/Gla/Gla300")

--[[
Unalienable Rights (Gla300 SEQ_015): J'moldva's challenge at the Wailing Barracks.
The fight is Content/Quest/QuestBattle.lua, variant Gla30001.
--]]

function init()
	return "/Director/Quest/QuestDirectorGla30001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Gla300",
		content = "SimpleContentGla30001",
		encounter = "QuestDirectorGla30001",
		sequence = SEQ_015,
		win = finishGla300Challenge,
		fail = failGla300Challenge,
	})
end

function main()
end
