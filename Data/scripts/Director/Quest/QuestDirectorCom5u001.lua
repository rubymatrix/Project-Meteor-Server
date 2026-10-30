require("Global")
require("QuestDuty")
require("Quest/Com/Com5u0")

--[[
Com5u0: the Toto-Rak visit. The fight is Content/Quest/QuestBattle.lua, variant Com5Visit.
The client has no Com5 quest director, so this runs the dungeon's own director class.
--]]

function init()
	return "/Director/Occupancy/RaidFst0Dungeon03"
end

function onEventStarted(player, director, triggerName)
	runQuestBattle(player, director, {
		quest = "Com5u0",
		encounter = "QuestDirectorCom5u001",
		options = questBattleOptions,
	})
end

function main()
end
