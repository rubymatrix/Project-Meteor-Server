require("global.lua")

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onSequence(player, quest, seqNum)
	quest:ClearENpcs();	
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	
	
end

function onEmote(player, quest, npc, emote)
end

function onPush(player, quest, npc)
end

function onNotice(player, quest, npc)
end

function getJournalInformation(player, quest)
	return {};
end

function getJournalMapMarkerList(player, quest)
	return 11000105, 11000106;
end