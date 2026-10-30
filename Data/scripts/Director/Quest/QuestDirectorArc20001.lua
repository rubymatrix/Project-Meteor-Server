require("Global")
require("QuestFlow")
require("Quest/Arc/Arc200")

--[[
Filling the Quiver (Arc200 SEQ_020): Keelty's rendezvous at Fallgourd. Five yarzon invaders in one wave.
The fight is Content/Quest/QuestBattle.lua, variant Arc20001.
--]]

function init()
	return "/Director/Quest/QuestDirectorArc20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Arc200",
		content = "SimpleContentArc20001",
		encounter = "QuestDirectorArc20001",
		sequence = SEQ_020,
		win = finishInvaderFight,
		fail = failInvaderFight,
	})
end

function main()
end
