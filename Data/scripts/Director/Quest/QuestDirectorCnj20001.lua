require("Global")
require("QuestFlow")
require("Quest/Cnj/Cnj200")

--[[
Dendrological Duties (Cnj200 SEQ_010): Telent's culling east of Blue Badger Gate. Four rabid coywolves
one at a time, then their alpha.
The fight is Content/Quest/QuestBattle.lua, variant Cnj20001.
--]]

function init()
	return "/Director/Quest/QuestDirectorCnj20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Cnj200",
		content = "SimpleContentCnj20001",
		encounter = "QuestDirectorCnj20001",
		sequence = SEQ_010,
		win = finishCulling,
		fail = failCulling,
	})
end

function main()
end
