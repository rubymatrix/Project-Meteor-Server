-- Sequence Numbers
SEQ_000	= 0;  -- On the boat interior; contains the basics tutorial.
SEQ_005	= 5;  -- Combat on the top of the boat.
SEQ_010	= 10; -- In Limsa Lominsa's port.

-- Quest Flags
seq000_Flag_MainTut0	= false;
seq000_Flag_MiniTut1 	= false;
seq000_Flag_MiniTut2 	= false;
seq000_Flag_MiniTut3 	= false;

-- Map Markers
local seq000_Markers = {
	11000203, -- Rostnsthal
	11000204, -- Voluptuous Vixen
	11000205, -- Baby-faced Adventurer
};

-- Actors in this quest
NPC_WELLTRAVELED_MERCHANT = 0;
NPC_TIPSY_ADVENTURER = 0;
NPC_CULTIVATED_TENDER = 0;
NPC_ANXIOUS_ADVENTURER = 0;
NPC_BABYFACED_ADVENTURER = 0;
NPC_AUSTERE_ADVENTURER = 0;
NPC_UNDIGNIFIED_ADVENTURER = 0;
NPC_SHADOWY_TRAVELER = 0;
NPC_ASTUTE_MERCHANT = 0;
NPC_VOLUPTUOUS_VIXEN = 0;
NPC_INDIFFERENT_PASSERBY = 0;
NPC_PRATTLING_ADVENTURER = 0;
NPC_GRINNING_ADVENTURER = 0;
NPC_ROSTNSTHAL = 0;
NPC_EXIT_TRIGGER = 0;

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onSequence(player, quest, seqNum)
	quest:ClearENpcs();
	
	if (sequence == SEQ_000) then
		-- Setup states incase we loaded in.
		local rostnsthalQuestFlag = QFLAG_NONE;
		local rostnsthalCanPush = true;
		local rostnsthalCanTalk = false;
		if (seq000_Flag_MainTut0 == true) then
			rostnsthalCanTalk = true;
			rostnsthalCanPush = false;
			if (seq000_Flag_MiniTut1 == false) then				
				rostnsthalQuestFlag = QFLAG_BOTH;
			end
		else
			rostnsthalCanTalk = false;
			rostnsthalCanPush = true;
		end				
	
		quest:AddENpc(NPC_WELLTRAVELED_MERCHANT);
		quest:AddENpc(NPC_TIPSY_ADVENTURER);
		quest:AddENpc(NPC_CULTIVATED_TENDER);
		quest:AddENpc(NPC_ANXIOUS_ADVENTURER);
		quest:AddENpc(NPC_BABYFACED_ADVENTURER);
		quest:AddENpc(NPC_AUSTERE_ADVENTURER);
		quest:AddENpc(NPC_UNDIGNIFIED_ADVENTURER);
		quest:AddENpc(NPC_SHADOWY_TRAVELER);
		quest:AddENpc(NPC_ASTUTE_MERCHANT);
		quest:AddENpc(NPC_VOLUPTUOUS_VIXEN);
		quest:AddENpc(NPC_INDIFFERENT_PASSERBY);
		quest:AddENpc(NPC_PRATTLING_ADVENTURER);
		quest:AddENpc(NPC_GRINNING_ADVENTURER);
		quest:AddENpc(NPC_ROSTNSTHAL, rostnsthalQuestFlag, rostnsthalCanTalk, false, rostnsthalCanPush);
		quest:AddENpc(NPC_EXIT_TRIGGER);
	elseif (sequence == SEQ_005) then
	elseif (sequence == SEQ_010) then
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	
	if (sequence == SEQ_000) then
		seq000_onTalk(player, quest, npc, classId);
	elseif (sequence == SEQ_005) then
		sequence005_onTalk(player, quest, npc, classId);
	elseif (sequence == SEQ_010) then
		sequence010_onTalk(player, quest, npc, classId);
	end
	
end

function seq000_onTalk(player, quest, npc, classId)
	if (classId == NPC_WELLTRAVELED_MERCHANT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_4", nil, nil, nil);
	elseif (classId == NPC_TIPSY_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_5", nil, nil, nil);
	elseif (classId == NPC_CULTIVATED_TENDER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6", nil, nil, nil);
	elseif (classId == NPC_ANXIOUS_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_7", nil, nil, nil);
	elseif (classId == NPC_BABYFACED_ADVENTURER) then
		if (seq000_Flag_MiniTut3 == false) then
			callClientFunction(player, "delegateEvent", player, man0l0Quest, "processTtrMini003", nil, nil, nil);
			quest:UpdateENpc(FLAG, QFLAG_NONE);
			seq000_Flag_MiniTut3 = true;
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_8", nil, nil, nil);
		end
	elseif (classId == NPC_AUSTERE_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_9", nil, nil, nil);
	elseif (classId == NPC_UNDIGNIFIED_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_10", nil, nil, nil);
	elseif (classId == NPC_SHADOWY_TRAVELER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_11", nil, nil, nil);
	elseif (classId == NPC_ASTUTE_MERCHANT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_12", nil, nil, nil);
	elseif (classId == NPC_VOLUPTUOUS_VIXEN) then
		if (seq000_Flag_MiniTut2 == false) then
			callClientFunction(player, "delegateEvent", player, man0l0Quest, "processTtrMini002", nil, nil, nil);
			quest:UpdateENpc(classId, FLAG, QFLAG_NONE);
			seq000_Flag_MiniTut2 = true;
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_13", nil, nil, nil);
		end
	elseif (classId == NPC_INDIFFERENT_PASSERBY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_14", nil, nil, nil);
	elseif (classId == NPC_PRATTLING_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_15", nil, nil, nil);
	elseif (classId == NPC_LANKY_TRAVELER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_16", nil, nil, nil);
	elseif (classId == NPC_GRINNING_ADVENTURER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_17", nil, nil, nil);
	elseif (classId == NPC_ROSTNSTHAL) then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrMini001", nil, nil, nil);
		if (seq000_Flag_MiniTut1 == false) then
			quest:UpdateENpc(classId, FLAG, QFLAG_NONE);
			seq000_Flag_MiniTut1 = true;
		end
	elseif (classId == NPC_EXIT_TRIGGER) then
		doExitDoor(player, quest, npc);
		return;
	end	
	player:EndEvent();
	
	if (seq000_Flag_MiniTut1 == true and seq000_Flag_MiniTut2 == true and seq000_Flag_MiniTut3 == true) then
		quest:UpdateENpc(NPC_EXIT_TRIGGER, FLAG, QFLAG_BOTH);
		quest:UpdateENpc(NPC_EXIT_TRIGGER, CANPUSH, true);
	end
end

function sequence005_onTalk(player, quest, npc, classId)
end

function sequence010_onTalk(player, quest, npc, classId)
end

function onEmote(player, quest, npc, emote)
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	
	if (sequence == SEQ_000) then
		if (classId == NPC_EXIT_TRIGGER) then
			doExitDoor(player, quest, npc);
			return;
		elseif (classId == NPC_ROSTNSTHAL) then
			callClientFunction(player, "delegateEvent", player, man0l0Quest, "processTtrNomal002", nil, nil, nil);
			quest:UpdateENpc(NPC_ROSTNSTHAL, CANPUSH, false);
		end
	end
end

function onNotice(player, quest, npc)
end

function getJournalInformation(player, quest)
	return {};
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence();
	
	if (sequence == SEQ_000) then
		return seq000_Markers;
	end
end

function doExitDoor(player, quest, npc)
		local choice = callClientFunction(player, "delegateEvent", player, quest, "processEventNewRectAsk", nil);	
		if (choice == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2", nil, nil, nil, nil);
			player:EndEvent();
			
			quest:StartSequence(SEQ_005);
			
			contentArea = player:GetZone():CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "man0l01", "SimpleContent30002", "Quest/QuestDirectorMan0l001");
			
			if (contentArea == nil) then
				return;
			end
			
			director = contentArea:GetContentDirector();		
			player:AddDirector(director);		
			director:StartDirector(false);
			
			player:KickEvent(director, "noticeEvent", true);
			player:SetLoginDirector(director);		
			
			GetWorldManager():DoZoneChangeContent(player, contentArea, -5, 16.35, 6, 0.5, 16);		
			return;
		else
			player:EndEvent();
		end
end