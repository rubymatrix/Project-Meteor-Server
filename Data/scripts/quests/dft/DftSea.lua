--[[

Quest Script

Name: 	Small Talk
Code: 	DftSea
Id: 	110540

Contains all default lines for talkable npcs in the Sea Region (aka La Noscea).
* NOTE: This quest is active for all players at all times.
]]

-- [ActorClassId] = "client_function_name"
local defaultTalkSea = {
	[1234] = "defaultTalkWithLefchild_001" -- Lefchild
}

function onTalk(player, quest, npc, eventName)
	local clientFunc = defaultTalkSea[npc:GetActorClassId()];	
	callClientFunction(player, "delegateEvent", player, quest, clientFunc);
	player:EndEvent();
end

function IsQuestENPC(player, quest, npc)
	return defaultTalkSea[npc:GetActorClassId()] ~= nil;
end