require("Global")
require("QuestDuty")
require("Quest/Com/Com0g5")

--[[
Com0g5: the clay golem at the Rootslake. The fight is Content/Quest/QuestBattle.lua, variant Com0g501.
--]]

function init()
	return "/Director/Quest/QuestDirectorCom0g501"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com0g5",
		encounter = "QuestDirectorCom0g501"
	})
end

function main()
end
