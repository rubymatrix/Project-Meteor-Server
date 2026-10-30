require("Global")

--[[
Grand Company leve officer. Only the outsider talk is wired. Client event functions:
Data/Docs/Scripts/Chara/Npc/Populace/PopulaceCompanyGLPublisher.md.
--]]

function init(npc)
	return false, false, 0, 0
end

local gcOfficer = {
[1500222] = 1, -- Storm Sergeant Hammil
[1500223] = 1, -- Storm Sergeant Sternn
[1500224] = 2, -- Serpent Sergeant Cordwyk
[1500225] = 2, -- Serpent Sergeant Lodall
[1500226] = 3, -- Flame Sergeant Byrne
[1500227] = 3, -- Flame Sergeant Dalvag
}

function onEventStarted(player, npc, triggerName)

	callClientFunction(player, "talkOutsider")

	callClientFunction(player, "finishTalkTurn")
	player:EndEvent()
end

