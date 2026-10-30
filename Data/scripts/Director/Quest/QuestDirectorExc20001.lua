require("Global")
require("QuestFlow")
require("Quest/Exc/Exc200")

--[[
Bloody Baptism (Exc200 SEQ_005): Swiftperch Tower. Six tower lemmings, then two more and the Lord of
Swiftperch.
The fight is Content/Quest/QuestBattle.lua, variant Exc20001.
--]]

function init()
	return "/Director/Quest/QuestDirectorExc20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Exc200",
		content = "SimpleContentExc20001",
		encounter = "QuestDirectorExc20001",
		sequence = SEQ_005,
		win = finishSwiftperchDuty,
		fail = failSwiftperchDuty,
		reviveOnFail = true,
	})
end

function main()
end
