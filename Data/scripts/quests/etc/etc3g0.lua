require ("global")

--[[

Quest Script

Name: 	Seeing the Seers
Code: 	Etc3g0
Id: 	110674
Prereq: Level 5, Any Class

]]

-- Sequence Numbers
SEQ_000	= 0;  -- Talk to all the seers.
SEQ_001	= 1;  -- Return to Kinnison.

-- Actor Class Ids
KINNISON 		= 1001430;
SYBELL 			= 1001437;
KHUMA_MOSHROCA	= 1001081;
NELLAURE 		= 1000821;
MESTONNAUX 		= 1001103;
LEFWYNE 		= 1001396;

-- Quest Markers
MRKR_KINNISON		= 11080001
MRKR_SYBELL			= 11080002
MRKR_KHUMA_MOSHROCA	= 11080003
MRKR_NELLAURE		= 11080004
MRKR_MESTONNAUX		= 11080005
MRKR_LEFWYNE		= 11080006

-- Quest Flags
FLAG_TALKED_MESTONNAUX 		= 0;
FLAG_TALKED_SYBELL 			= 1;
FLAG_TALKED_NELLAURE 		= 2;
FLAG_TALKED_KHUMA_MOSHROCA 	= 3;
FLAG_TALKED_LEFWYNE 		= 4;

--offerQuestResult = callClientFunction(player, "delegateEvent", player, quest, "processEventOffersStart");

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onSequence(player, quest, sequence)	
	quest:ClearENpcs();	
	
	if (sequence == SEQ_000) then
		quest:AddENpc(SYBELL, qflag(quest, FLAG_TALKED_SYBELL));
		quest:AddENpc(KHUMA_MOSHROCA, qflag(quest, FLAG_TALKED_KHUMA_MOSHROCA));
		quest:AddENpc(NELLAURE, qflag(quest, FLAG_TALKED_NELLAURE));
		quest:AddENpc(MESTONNAUX, qflag(quest, FLAG_TALKED_MESTONNAUX));
		quest:AddENpc(LEFWYNE, qflag(quest, FLAG_TALKED_LEFWYNE));
	elseif (sequence == SEQ_001) then
		quest:AddENpc(KINNISON);
	end	
end

function qflag(quest, flag)
	return quest:GetFlag(flag) and QFLAG_ALL or QFLAG_NONE;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc:GetActorClassId();
	local seq = quest:GetSequence();
	
	if (seq == SEQ_000) then
		if (npcClassId == SYBELL) then
			if (not quest:GetFlag(FLAG_TALKED_SYBELL)) then
				callClientFunction(player, "delegateEvent", player, quest, "processEventSybellSpeak");
				quest:SetFlag(FLAG_TALKED_SYBELL);
				--quest:UpdateENpc(SYBELL, QFLAG_NONE);				
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventSybellSpeakAfter");
			end
		elseif (npcClassId == KHUMA_MOSHROCA) then
			if (not quest:GetFlag(FLAG_TALKED_KHUMA_MOSHROCA)) then
				callClientFunction(player, "delegateEvent", player, quest, "processEventKhumaSpeak");
				quest:SetFlag(FLAG_TALKED_KHUMA_MOSHROCA);
				--quest:UpdateENpc(KHUMA_MOSHROCA, QFLAG_NONE);				
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventKhumaSpeakAfter");
			end
		elseif (npcClassId == NELLAURE) then
			if (not quest:GetFlag(FLAG_TALKED_NELLAURE)) then
				callClientFunction(player, "delegateEvent", player, quest, "processEventNellaureSpeak");
				quest:SetFlag(FLAG_TALKED_NELLAURE);
				--quest:UpdateENpc(NELLAURE, QFLAG_NONE);				
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventNellaureSpeakAfter");
			end
		elseif (npcClassId == MESTONNAUX) then
			if (not quest:GetFlag(FLAG_TALKED_MESTONNAUX)) then
				callClientFunction(player, "delegateEvent", player, quest, "processEventMestonnauxSpeak");
				quest:SetFlag(FLAG_TALKED_MESTONNAUX);
				--quest:UpdateENpc(MESTONNAUX, QFLAG_NONE);				
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventMestonnauxSpeakAfter");
			end
		elseif (npcClassId == LEFWYNE) then
			if (not quest:GetFlag(FLAG_TALKED_LEFWYNE)) then
				callClientFunction(player, "delegateEvent", player, quest, "processEventLefwyneSpeak");
				quest:SetFlag(FLAG_TALKED_LEFWYNE);
				--quest:UpdateENpc(LEFWYNE, QFLAG_NONE);				
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEventLefwyneSpeakAfter");
			end
		end
		
		-- Check condition to go to the next sequence
		if (seq000_checkCondition(quest)) then
			quest:StartSequence(SEQ_001);
		end
	elseif (seq == SEQ_001) then
		--Quest Complete
		if (npcClassId == KINNISON) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 1, 1, 9);
		end
	end
	
	player:EndEvent();
end

-- Check if all seers are talked to
function seq000_checkCondition(quest)
	return (quest:GetFlag(FLAG_TALKED_SYBELL) and
			quest:GetFlag(FLAG_TALKED_KHUMA_MOSHROCA) and
			quest:GetFlag(FLAG_TALKED_NELLAURE) and
			quest:GetFlag(FLAG_TALKED_MESTONNAUX) and
			quest:GetFlag(FLAG_TALKED_LEFWYNE));
end

-- This is called by the RequestQuestJournalCommand when map markers are request.
-- Check quest_marker for valid values. This should return a table of map markers.
function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	
	if (seq == SEQ_000) then
		return MRKR_SYBELL, MRKR_KHUMA_MOSHROCA, MRKR_NELLAURE, MRKR_MESTONNAUX, MRKR_LEFWYNE;
	elseif (seq == SEQ_001) then
		return MRKR_KINNISON;
	end
end