require("Global")
require("QuestFlow")
require("Quest/Thm/Thm300")

--[[
Revelry in Rivalry (Thm300 SEQ_010): the Ignis Fatuus at the bizarre blacksmith's. The wisp turns on the
smith first; whether the smith lives picks Bodenolf's report.
The fight is Content/Quest/QuestBattle.lua, variant Thm30001.
--]]

function init()
	return "/Director/Quest/QuestDirectorThm30001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Thm300",
		content = "SimpleContentThm30001",
		encounter = "QuestDirectorThm30001",
		sequence = SEQ_010,
		win = function(player, quest, fight, area)
			finishIgnisFatuus(player, quest, fight, area, fight:GroupAlive("allies") > 0)
		end,
		fail = failIgnisFatuus,
		reviveOnFail = true,
	})
end

function main()
end
