require("Global")
require("QuestDuty")
require("Quest/Com/Com5u1")

--[[
Com5u1: the Dzemael Darkhold visit. The fight is Content/Quest/QuestBattle.lua, variant Com5Visit.
The client has no Com5 quest director, so this runs the dungeon's own director class.
--]]

function init()
	return "/Director/Occupancy/RaidRoc0Dungeon01"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com5u1",
		encounter = "QuestDirectorCom5u101",
		options = questBattleOptions,
	})
end

function main()
end
