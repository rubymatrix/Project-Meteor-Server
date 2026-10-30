require("Global")
--[[
Small Talk (DftLak, 110545): default lines for the talkable NPCs of the Lak region (Mor Dhona),
active for every player at all times. Not wired, since no display name matches them: Rashaht,
Myrganmoen, Hidden, Quinquerol, Tall, Vevina, Jakys, Mhenall, Clovissoix.
--]]

local defaultTalkLak = {
	[1001913] = "defaultTalkWithMemenugu_001",            -- Camp Brittlebark
	[1001900] = "defaultTalkWithLangliva_001",            -- Camp Brittlebark
	[1001922] = "defaultTalkWithEidinsath_001",           -- Camp Revenant's Toll
}

function onTalk(player, quest, npc, eventName)
	local clientFunc = defaultTalkLak[npc:GetActorClassId()]
	callClientFunction(player, "delegateEvent", player, quest, clientFunc)
	player:EndEvent()
end

function IsQuestENPC(player, quest, npc)
	return defaultTalkLak[npc:GetActorClassId()] ~= nil
end
