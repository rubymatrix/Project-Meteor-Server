require ("global")
require ("quest")
require ("tutorial")
require ("modifiers")
--[[

Quest Script

Name:   Souls Gone Wild
Code:   Man0g1
Id:     110006
Prereq: Sundered Skies (Man0g0 - 110005)
Notes:

]]

ENABLE_GL_TUTORIAL = false;

AFTER_WARP_NOTICE = true;

-- Sequence Numbers
SEQ_000 = 0;	-- (Private Area) Roost Echo Scene.
SEQ_005 = 5;	-- Go attune at Camp Bentbranch
SEQ_010 = 10;	-- Attuned, go back to Miuonne. Info: <param1> If 1, Miounne gave you a tutorial guildleve else 0.
SEQ_012 = 12;	-- Talk to Miuonne again.
SEQ_015 = 15;	-- Find the LTW and CNJ Guilds. Info: Params 2 and 3 set to 5 and 15 will show the msg that you visited both guilds and to notify Baderon on the LS.
SEQ_040 = 40;	-- Go to BTN guild and talk to Opyltyl.
SEQ_050 = 50;	-- Learn the dance from the kids.
SEQ_055 = 55;	-- Chat with the kids.
SEQ_060 = 60;	-- Meet at White Wolf Gate.
SEQ_065 = 65;	-- Escort Mission Duty
SEQ_070 = 70;	-- Walk to the stump.
SEQ_071 = 71;	-- Exit the stump area.
SEQ_072 = 72;	-- Return to the BTN guild.
SEQ_075 = 75;	-- Contact Miounne on LS
SEQ_080 = 80;	-- Visit the LNC guid and talk to Willelda.
SEQ_085 = 85;	-- Talk to Buchard.
SEQ_090 = 90;	-- Talk to Buchard again.
SEQ_095 = 95;	-- Talk to Nuala.
SEQ_100 = 100;	-- Contact Miounne on LS
SEQ_105 = 105;	-- Return to the Roost and talk to Miounne.

-- Quest Data
FLAG_EMOTE_DONE1	= 1;
FLAG_EMOTE_DONE2	= 2;
FLAG_EMOTE_DONE3	= 3;
FLAG_EMOTE_DONE4	= 4;
FLAG_EMOTE_DONE5	= 5;
FLAG_EMOTE_DONE6	= 6;

CNTR_SEQ15_LTW		= 0;
CNTR_SEQ15_CNJ		= 1;

GIL_LTW_PAID		= 2000;
GIL_ESCORT_PAID		= 3000;


-- Msg packs for the Npc LS
NPCLS_MSGS = {
	{330},
	{332, 333, 334, 335},
	{131, 132, 133},
	{210, 211, 212, 213, 214, 215},
	{322, 323, 324}
};

-- Actor Class Ids
MIOUNNE                         = 1000230;
VKOROLON                        = 1000458;
WISPILY_WHISKERED_WOODWORKER    = 1000562;
AMIABLE_ADVENTURER              = 1001057;
MOROSE_MERCHANT                 = 1001058;
NARROW_EYED_ADVENTURER          = 1001059;
BEAMING_ADVENTURER              = 1001062;
WELL_BUNDLED_ADVENTURER         = 1001060;
UNCONCERNED_PASSERBY            = 1001648;
--BLOCKER                       = ;

-- Sequence 015
HEREWARD		= 1000231;
SOILEINE		= 1000234;
CNJ_TRIG		= 1090200;

-- Echo in the CNJ Guild
YDA				= 1000009;
PAPALYMO		= 1000010;
O_APP_PESI		= 1000033;
INGRAM			= 1000372;
HETZKIN			= 1000460;
GUGULA			= 1000513;
SWETHYNA		= 1000680;
BIDDY			= 1000737;
CHALLINIE		= 1000956;

-- BTN Guild
OPYLTYL			= 1000236;
FUFUCHA			= 1000237;
POWLE			= 1000238;
SANSA			= 1000239;
NICOLLAUX		= 1000409;
AUNILLE			= 1000410;
ELYN			= 1000411;
RYD				= 1000412;
KIDS_TRIGGER	= 1090201;
GATE_TRIGGER	= 1090202;

-- Post Escort Duty
STUMP_TRIGGER		= 1090203;
STUMP_EXIT_TRIGGER	= 1090204;
BTN_TRIGGER			= 1090046;

-- LNC Guild
WILLELDA		= 1000242;
BURCHARD		= 1000243;

-- Echo in the LNC Guild
TKEBBE			= 1000015;
FARRIMOND		= 1000017;
NUALA			= 1000681;
MANSEL			= 1000682;
CECILIA			= 1000683;
TURSTIN			= 1000733;
LANGLOISIERT	= 1000734;
HELBHANTH		= 1000735;
PASDEVILLET		= 1000738;
JIJIMAYA		= 1000741;

-- Quest Markers
MRKR_MIOUNNE			= 11000601;
MRKR_BENTBRANCH			= 11000602;
MRKR_MIOUNNE2			= 11000603;
MRKR_HEREWARD			= 11000604;
MRKR_SOILEINE			= 11000605;
MRKR_CNJ_TRIGGER		= 11000606;
MRKR_SWETHYNA			= 11000607;
MRKR_OPYLTYL			= 11000608;
MRKR_KIDS_PRACTICE		= 11000609;
MRKR_KIDS_TRIGGER		= 11000610;
MRKR_GATE_TRIGGER		= 11000611;
MRKR_LIFEMEND_STUMP		= 11000612;
MRKR_STUMP_TRIGGER		= 11000613;
MRKR_STUMP_EXIT_TRIGGER	= 11000614;
MRKR_BTN_TRIGGER		= 11000615;
MRKR_WILLELDA			= 11000616;
MRKR_BURCHARD			= 11000617;
MRKR_BURCHARD2			= 11000618;
MRKR_NUALA				= 11000619;
MRKR_MIOUNNE3			= 11000620;

function onStart(player, quest)
    quest:StartSequence(SEQ_000);

	callClientFunction(player, "delegateEvent", player, quest, "processEvent100");
	player:EndEvent();
	GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", 2, 15, 67.034, 4, -1205.6497, -1.074);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();

    if (sequence == SEQ_000) then
        quest:SetENpc(MIOUNNE, QFLAG_TALK);
        quest:SetENpc(VKOROLON);
        quest:SetENpc(WISPILY_WHISKERED_WOODWORKER);
        quest:SetENpc(AMIABLE_ADVENTURER);
        quest:SetENpc(MOROSE_MERCHANT);
        quest:SetENpc(NARROW_EYED_ADVENTURER);
        quest:SetENpc(BEAMING_ADVENTURER);
        quest:SetENpc(WELL_BUNDLED_ADVENTURER);
        quest:SetENpc(UNCONCERNED_PASSERBY);
    elseif (sequence == SEQ_005) then
        quest:SetENpc(MIOUNNE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(MIOUNNE, QFLAG_TALK);
	elseif (sequence == SEQ_012) then
		quest:SetENpc(MIOUNNE, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		local subseqLTW = data:GetCounter(CNTR_SEQ15_LTW);
		local subseqCNJ = data:GetCounter(CNTR_SEQ15_CNJ);
		local herewardOwed = (subseqLTW == 0) or (subseqLTW == 1 and subseqCNJ >= 3 and data:GetNpcLsFrom() == 0);
		-- Always active in this seqence
		quest:SetENpc(MIOUNNE);
		quest:SetENpc(HEREWARD, herewardOwed and QFLAG_TALK or QFLAG_OFF);
		-- CNJ and In Echo
		quest:SetENpc(SOILEINE, (subseqCNJ == 0) and QFLAG_TALK or QFLAG_OFF);
		quest:SetENpc(CNJ_TRIG, (subseqCNJ == 1) and QFLAG_PUSH or QFLAG_OFF, false, (subseqCNJ == 1));
		quest:SetENpc(YDA);
		quest:SetENpc(PAPALYMO);
		quest:SetENpc(O_APP_PESI);
		quest:SetENpc(SWETHYNA, (subseqCNJ == 2) and QFLAG_TALK or QFLAG_OFF);
		quest:SetENpc(INGRAM);
		quest:SetENpc(HETZKIN);
		quest:SetENpc(GUGULA);
		quest:SetENpc(BIDDY);
		quest:SetENpc(CHALLINIE);
	elseif (sequence == SEQ_040) then
        quest:SetENpc(OPYLTYL, QFLAG_TALK);
		quest:SetENpc(MIOUNNE);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(OPYLTYL, QFLAG_TALK);
        quest:SetENpc(AUNILLE, not data:GetFlag(FLAG_EMOTE_DONE1) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE1));
		quest:SetENpc(NICOLLAUX, not data:GetFlag(FLAG_EMOTE_DONE2) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE2));
		quest:SetENpc(SANSA, not data:GetFlag(FLAG_EMOTE_DONE3) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE3));
		quest:SetENpc(POWLE, not data:GetFlag(FLAG_EMOTE_DONE4) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE4));
		quest:SetENpc(RYD, not data:GetFlag(FLAG_EMOTE_DONE5) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE5));
		quest:SetENpc(ELYN, not data:GetFlag(FLAG_EMOTE_DONE6) and QFLAG_TALK or QFLAG_OFF, true, false, not data:GetFlag(FLAG_EMOTE_DONE6));
		quest:SetENpc(FUFUCHA);
	elseif (sequence == SEQ_055) then
		quest:SetENpc(OPYLTYL, QFLAG_TALK);
		quest:SetENpc(KIDS_TRIGGER, QFLAG_PUSH, false, true);
        quest:SetENpc(AUNILLE);
		quest:SetENpc(NICOLLAUX);
		quest:SetENpc(SANSA);
		quest:SetENpc(POWLE);
		quest:SetENpc(RYD);
		quest:SetENpc(ELYN);
		quest:SetENpc(FUFUCHA);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(GATE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_065) then
		quest:SetENpc(GATE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(STUMP_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_071) then
		quest:SetENpc(STUMP_EXIT_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_072) then
		quest:SetENpc(BTN_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_075) then
	elseif (sequence == SEQ_080) then
		quest:SetENpc(WILLELDA, QFLAG_TALK);
		quest:SetENpc(MIOUNNE);
	elseif (sequence == SEQ_085) then
		quest:SetENpc(BURCHARD, QFLAG_TALK);
		quest:SetENpc(WILLELDA);
	elseif (sequence == SEQ_090) then
		quest:SetENpc(BURCHARD, QFLAG_TALK);
		quest:SetENpc(TKEBBE);
		quest:SetENpc(FARRIMOND);
		quest:SetENpc(LANGLOISIERT);
		quest:SetENpc(NUALA);
		quest:SetENpc(MANSEL);
		quest:SetENpc(CECILIA);
		quest:SetENpc(TURSTIN);
		quest:SetENpc(HELBHANTH);
		quest:SetENpc(PASDEVILLET);
		quest:SetENpc(JIJIMAYA);
	elseif (sequence == SEQ_095) then
		quest:SetENpc(NUALA, QFLAG_TALK);
		quest:SetENpc(BURCHARD);
		quest:SetENpc(JIJIMAYA);
		quest:SetENpc(TKEBBE);
		quest:SetENpc(FARRIMOND);
		quest:SetENpc(MANSEL);
		quest:SetENpc(CECILIA);
	elseif (sequence == SEQ_100) then
		quest:SetENpc(NUALA);
		quest:SetENpc(BURCHARD);
		quest:SetENpc(WILLELDA);
	elseif (sequence == SEQ_105) then
		quest:SetENpc(MIOUNNE, QFLAG_REWARD);
		quest:SetENpc(NUALA);
		quest:SetENpc(BURCHARD);
		quest:SetENpc(WILLELDA);
    end
end

function onTalk(player, quest, npc)
    local sequence = quest:GetSequence();
    local classId = npc:GetActorClassId();

    if (sequence == SEQ_000) then
        if (seq000_onTalk(player, quest, npc, classId) == true) then
			return;
		end
    elseif (sequence == SEQ_005) then
		if (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent110_2");
		end
	elseif (sequence == SEQ_010) then
		if (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent114");
			quest:StartSequence(SEQ_012);
		end
	elseif (sequence == SEQ_012) then
		if (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent115");
			quest:NewNpcLsMsg(1);
			quest:StartSequence(SEQ_015);
		end
	elseif (sequence == SEQ_015) then
		if (seq015_onTalk(player, quest, npc, classId) == true) then
			return;
		end
	elseif (sequence == SEQ_040) then
		if (classId == OPYLTYL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140");
			quest:StartSequence(SEQ_050);
			player:EndEvent();
			warpToEcho(player, 1, -223.792, 12, -1498.369, -1.74);
			return;
		elseif (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent137_2");
		end
	elseif (sequence == SEQ_050) then
		if (classId == OPYLTYL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent1000_3");
			player:EndEvent();
			warpToEcho(player, 1, -223.792, 12, -1498.369, -1.74);
			return;
		else
			seq050_onTalk(player, quest, npc, classId);
		end
	elseif (sequence == SEQ_055) then
		if (classId == FUFUCHA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent150_2");
		elseif (classId == OPYLTYL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent1000_3");
			player:EndEvent();
			warpToEcho(player, 2, -231.474, 12, -1500.86, 0.73);
			return;
		elseif (classId == AUNILLE or classId == NICOLLAUX or classId == SANSA or classId == POWLE or classId == RYD or classId == ELYN) then
			local randNum = math.random(1, 2);
			if (randNum == 1) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent150_3");
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent150_4");
			end
		end
	elseif (sequence == SEQ_060) then
	elseif (sequence == SEQ_065) then
	elseif (sequence == SEQ_070) then
	elseif (sequence == SEQ_071) then
	elseif (sequence == SEQ_072) then
	elseif (sequence == SEQ_075) then
	elseif (sequence == SEQ_080) then
		if (classId == WILLELDA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent190");
			quest:StartSequence(SEQ_085);
		elseif (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent185_2");
		end
	elseif (sequence == SEQ_085) then
		if (classId == BURCHARD) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200");
			quest:StartSequence(SEQ_090);
			player:EndEvent();
			GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", 3, 15, 176.13, 27.5, -1581.84, -1.0);
			return;
		elseif (classId == WILLELDA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent190_2");
		end
	elseif (sequence == SEQ_090) then
		if (classId == BURCHARD) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent210");
			quest:StartSequence(SEQ_095);
			player:EndEvent();
			GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", 4, 15, 177.0, 27.5, -1581.0, 1.6);
			return;
		elseif (classId == NUALA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_2");
		elseif (classId == TKEBBE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_3");
		elseif (classId == FARRIMOND) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_4");
		elseif (classId == MANSEL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_5");
		elseif (classId == JIJIMAYA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_6");
		elseif (classId == LANGLOISIERT) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_7");
		elseif (classId == CECILIA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_8");
		elseif (classId == TURSTIN) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_9");
		elseif (classId == HELBHANTH) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_10");
		elseif (classId == PASDEVILLET) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_11");
		end
	elseif (sequence == SEQ_095) then
		if (classId == NUALA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220");
			player:EndEvent();
			quest:NewNpcLsMsg(1);
			quest:StartSequence(SEQ_100);
			GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, 176.13, 27.5, -1581.84, -1.0);
			return;
		elseif (classId == BURCHARD) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent210_2");
		elseif (classId == TKEBBE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_3");
		elseif (classId == FARRIMOND) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_4");
		elseif (classId == MANSEL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_5");
		elseif (classId == JIJIMAYA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_6");
		elseif (classId == CECILIA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent200_8");
		end
	elseif (sequence == SEQ_100) then
		if (classId == NUALA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent1000_5");
		elseif (classId == BURCHARD) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220_3");
		elseif (classId == WILLELDA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220_2");
		end
	elseif (sequence == SEQ_105) then
		if (classId == MIOUNNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventComplete");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 300, 1, 1, 2);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		elseif (classId == NUALA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent1000_5");
		elseif (classId == BURCHARD) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220_3");
		elseif (classId == WILLELDA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent220_2");
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function seq000_onTalk(player, quest, npc, classId)
    if (classId == MIOUNNE) then

        callClientFunction(player, "delegateEvent", player, quest, "processEvent110");
		quest:NewNpcLsMsg(1);
		quest:StartSequence(SEQ_005);
        player:EndEvent();

		local director = GetWorldManager():GetArea(155):CreateDirector("AfterQuestWarpDirector", false);
		player:AddDirector(director);
		director:StartDirector(true);
		player:SetLoginDirector(director);
		player:KickEvent(director, "noticeEvent", true);

        GetWorldManager():DoZoneChange(player, 155, nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation);
		return true;

    elseif (classId == BEAMING_ADVENTURER) then
        callClientFunction (player, "delegateEvent", player, quest, "processEvent100_6");
    elseif (classId == AMIABLE_ADVENTURER) then
        callClientFunction (player, "delegateEvent", player, quest, "processEvent100_3");
    elseif (classId == MOROSE_MERCHANT) then
        callClientFunction (player, "delegateEvent", player, quest, "processEvent100_2");
    elseif (classId == NARROW_EYED_ADVENTURER) then
        callClientFunction(player, "delegateEvent", player, quest, "processEvent100_7");
    elseif (classId == UNCONCERNED_PASSERBY) then
        callClientFunction(player, "delegateEvent", player, quest, "processEvent100_9");
    elseif (classId == VKOROLON) then
        callClientFunction(player, "delegateEvent", player, GetStaticActor("DftWil"), "defaultTalkWithVkorolon_001");
    elseif (classId == WELL_BUNDLED_ADVENTURER) then
        callClientFunction(player, "delegateEvent", player, quest, "processEvent100_4");
    elseif (classId == WISPILY_WHISKERED_WOODWORKER) then
        callClientFunction(player, "delegateEvent", player, quest, "processEvent100_8");
    end

end

function seq015_onTalk(player, quest, npc, classId)
	local data = quest:GetData();
	local subseqLTW = data:GetCounter(CNTR_SEQ15_LTW);
	local subseqCNJ = data:GetCounter(CNTR_SEQ15_CNJ);

	if (classId == MIOUNNE) then
		if (subseqCNJ >= 3) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent135_2");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent115_2");
		end
	-- LTW Guild Events
	elseif (classId == HEREWARD) then
		if (subseqLTW == 0) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent120");
			data:SetCounter(CNTR_SEQ15_LTW, 1);
			data:Save();
			player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_LTW_PAID, 1);
			if (subseqCNJ >= 3) then
				seq015_endSequence(player, quest);
			end
		elseif (subseqLTW == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent120_2");
			data:SetCounter(CNTR_SEQ15_LTW, 2);
			data:Save();
			if (subseqCNJ >= 3 and data:GetNpcLsFrom() == 0) then
				seq015_endSequence(player, quest);
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent120_2");
		end
	-- CNJ Guild and Echo
	elseif (classId == SOILEINE) then
		if (subseqCNJ == 0) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent125");
			data:SetCounter(CNTR_SEQ15_CNJ, 1);
			data:Save();
		elseif (subseqCNJ == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent125_2");
		elseif (subseqCNJ == 2) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent125_2");
		end
	elseif (classId == O_APP_PESI) then
		if (subseqCNJ == 1) then
			seq015_enterEcho(player, quest);
			return true;
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent130_3");
		end
	elseif (classId == YDA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_4");
	elseif (classId == PAPALYMO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_5");
	elseif (classId == GUGULA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_6");
	elseif (classId == INGRAM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_7");
	elseif (classId == CHALLINIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_8");
	elseif (classId == HETZKIN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_2");
	elseif (classId == BIDDY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent130_2");
	elseif (classId == SWETHYNA) then
		if (subseqCNJ >= 2) then
			if (subseqLTW == 0) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent135");
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent136");
			end
			if (subseqCNJ == 2) then
				data:SetCounter(CNTR_SEQ15_CNJ, 3);
				data:Save();
				if (subseqLTW >= 1) then
					quest:NewNpcLsMsg(1);
				end
			end
			player:EndEvent();
			quest:UpdateENPCs();
			GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, -350.0, 6.25, -1690.0, -2.4);
			return true;
		end
	end
end

function seq015_endSequence(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent123");
	quest:NewNpcLsMsg(1);
end

function seq015_enterEcho(player, quest)
	local data = quest:GetData();
	callClientFunction(player, "delegateEvent", player, quest, "processEvent130");
	data:SetCounter(CNTR_SEQ15_CNJ, 2);
	data:Save();
	player:EndEvent();
	quest:UpdateENPCs();
	GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", 0, 15, -353.05, 6.25, -1697.39, 0.774);
end

function seq050_onTalk(player, quest, npc, classId)
	local data = quest:GetData();

	if (classId == AUNILLE) then
		if (not data:GetFlag(FLAG_EMOTE_DONE1)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_1");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_1");
		end
	elseif (classId == NICOLLAUX) then
		if (not data:GetFlag(FLAG_EMOTE_DONE2)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_2");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_2");
		end
	elseif (classId == SANSA) then
		if (not data:GetFlag(FLAG_EMOTE_DONE3)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_3");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_3");
		end
	elseif (classId == POWLE) then
		if (not data:GetFlag(FLAG_EMOTE_DONE4)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_4");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_4");
		end
	elseif (classId == RYD) then
		if (not data:GetFlag(FLAG_EMOTE_DONE5)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_5");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_5");
		end
	elseif (classId == ELYN) then
		if (not data:GetFlag(FLAG_EMOTE_DONE6)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent140_6");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent141_6");
		end
	elseif (classId == FUFUCHA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent140_10");
	end
end

function warpToEcho(player, privateAreaType, x, y, z, rot)
	local area = player.CurrentArea;
	if (area.ZoneId == 155 and area:IsPrivate() and area:GetPrivateAreaName() == "PrivateAreaMasterPast" and area:GetPrivateAreaType() == privateAreaType) then
		GetWorldManager():DoPlayerMoveInZone(player, x, y, z, rot);
	else
		GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", privateAreaType, 15, x, y, z, rot);
	end
end

function onPush(player, quest, npc)
    local sequence = quest:GetSequence();
    local classId = npc:GetActorClassId();
	local data = quest:GetData();
	local subseqCNJ = data:GetCounter(CNTR_SEQ15_CNJ);

    if (sequence == SEQ_000) then
    elseif (sequence == SEQ_015) then
		if (classId == CNJ_TRIG and subseqCNJ == 1) then
			seq015_enterEcho(player, quest);
			return;
		end
	elseif (sequence == SEQ_055) then
		if (classId == KIDS_TRIGGER) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent160");
			player:EndEvent();
			quest:StartSequence(SEQ_060);
			GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, -209.817, 18, -1477.372, 1.4);
			return;
		end
	elseif (sequence == SEQ_060 or sequence == SEQ_065) then
		if (classId == GATE_TRIGGER) then
			local result = callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass");
			if (result == 1) then
				startMan0g1Content(player, quest);
				return;
			end
		end
	elseif (sequence == SEQ_070) then
		if (classId == STUMP_TRIGGER) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent181");
			player:EndEvent();
			quest:StartSequence(SEQ_071);
			GetWorldManager():DoZoneChange(player, 150, "PrivateAreaMasterPast", 1, 15, -756.77, 22.77, -1092.33, 2.4);
			return;
		end
	elseif (sequence == SEQ_071) then
		if (classId == STUMP_EXIT_TRIGGER) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent182");
			player:EndEvent();
			quest:StartSequence(SEQ_072);
			GetWorldManager():DoZoneChange(player, 155, nil, 0, 15, -185, 6, -962, -3);
			return;
		end
	elseif (sequence == SEQ_072) then
		if (classId == BTN_TRIGGER) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent185");
			player:GetItemPackage(INVENTORY_CURRENCY):AddItem(1000001, GIL_ESCORT_PAID, 1);
			player:EndEvent();
			quest:NewNpcLsMsg(1);
			quest:StartSequence(SEQ_075);
			return;
		end
    end
	player:EndEvent();
	quest:UpdateENPCs();
end

function onEmote(player, quest, npc, eventName)
	local data = quest:GetData();
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence ~= SEQ_050) then
		player:EndEvent();
		return;
	end

	-- Play the emote
	if (classId == AUNILLE) then		-- Beckon
		player:DoEmote(npc.Id, 8, 21071);
	elseif (classId == NICOLLAUX) then	-- Clap
		player:DoEmote(npc.Id, 7, 21061);
	elseif (classId == SANSA) then		-- Bow
		player:DoEmote(npc.Id, 5, 21041);
	elseif (classId == POWLE) then 		-- Cheer
		player:DoEmote(npc.Id, 6, 21051);
	elseif (classId == RYD) then		-- Surprised
		player:DoEmote(npc.Id, 1, 21001);
	elseif (classId == ELYN) then		-- Lookout
		player:DoEmote(npc.Id, 22, 21211);
	else
		player:EndEvent();
		return;
	end
	wait(2.5);

	-- Handle the result
	if (classId == AUNILLE) then
		if (not data:GetFlag(FLAG_EMOTE_DONE1)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_1");
			data:SetFlag(FLAG_EMOTE_DONE1);
		end
	elseif (classId == NICOLLAUX) then
		if (not data:GetFlag(FLAG_EMOTE_DONE2)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_2");
			data:SetFlag(FLAG_EMOTE_DONE2);
		end
	elseif (classId == SANSA) then
		if (not data:GetFlag(FLAG_EMOTE_DONE3)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_3");
			data:SetFlag(FLAG_EMOTE_DONE3);
		end
	elseif (classId == POWLE) then
		if (not data:GetFlag(FLAG_EMOTE_DONE4)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_4");
			data:SetFlag(FLAG_EMOTE_DONE4);
		end
	elseif (classId == RYD) then
		if (not data:GetFlag(FLAG_EMOTE_DONE5)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_5");
			data:SetFlag(FLAG_EMOTE_DONE5);
		end
	elseif (classId == ELYN) then
		if (not data:GetFlag(FLAG_EMOTE_DONE6)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent142_6");
			data:SetFlag(FLAG_EMOTE_DONE6);
		end
	end
	data:Save();

	-- Check result and finish
	if (bit.band(data:GetFlags(), 0x7E) == 0x7E) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent150");
		player:EndEvent();
		quest:StartSequence(SEQ_055);
		warpToEcho(player, 2, -231.474, 12, -1500.86, 0.73);
		return
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onNotice(player, quest, target)
	if (quest:GetSequence() == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
		callClientFunction(player, "delegateEvent", player, quest, "processEventTu_001");
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:GetSequence();
	local data = quest:GetData();
	local errandsDone = data:GetCounter(CNTR_SEQ15_LTW) >= 1 and data:GetCounter(CNTR_SEQ15_CNJ) >= 3;
	local msgPack;

	if (from == 1) then
		-- Get the right msg pack
		if (sequence == SEQ_005) then
			msgPack = 1;
		elseif (sequence == SEQ_015 and not errandsDone) then
			msgPack = 2;
		elseif (sequence == SEQ_015 or sequence == SEQ_040) then
			msgPack = 3;
		elseif (sequence == SEQ_075 or sequence == SEQ_080) then
			msgPack = 4;
		elseif (sequence == SEQ_100 or sequence == SEQ_105) then
			msgPack = 5;
		end

		if (msgPack == nil) then
			player:EndEvent();
			return;
		end

		-- Quick way to handle all msgs nicely.
		local msgs = NPCLS_MSGS[msgPack];
		local step = math.max(1, math.min(msgStep, #msgs));
		player:SendGameMessageLocalizedDisplayName(quest, msgs[step], MESSAGE_TYPE_NPC_LINKSHELL, 1300018);
		if (step >= #msgs) then
			quest:EndOfNpcLsMsgs();
		else
			quest:ReadNpcLsMsg();
		end

		-- Handle anything else
		if (sequence == SEQ_005) then
			showTutorialSuccessWidget(player, 9080);
			closeTutorialWidget(player);
			endTutorialMode(player);
		elseif (sequence == SEQ_015 and errandsDone) then
			quest:StartSequenceForNpcLs(SEQ_040);
		elseif (sequence == SEQ_075) then
			quest:StartSequenceForNpcLs(SEQ_080);
		elseif (sequence == SEQ_100) then
			quest:StartSequenceForNpcLs(SEQ_105);
		end
	end

	player:EndEvent();
end

function startMan0g1Content(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent170");
	if (quest:GetSequence() ~= SEQ_065) then
		quest:StartSequence(SEQ_065);
	end

	local contentArea = GetWorldManager():GetZone(150):CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "simplecontentman0g101", "SimpleContentMan0g101", "Quest/QuestDirectorMan0g101");

	if (contentArea == nil) then
		player:EndEvent();
		return;
	end

	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:SetLoginDirector(director);
	player:EndEvent();
	-- The kick must ride the warp: sent earlier, the client's notice record is corrupted.
	player:KickEvent(director, "noticeEvent", true);
	GetWorldManager():DoZoneChangeContent(player, contentArea, -194.73, 3.54, -1021.33, -1.642, 15);
end

function endMan0g1Content(player, duty, contentArea)
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:EndEvent();
	if (duty ~= nil) then
		duty:Close();
	end
	if (contentArea ~= nil) then
		pcall(function() contentArea:ContentFinished(); end);
	end
end

function finishEscort(player, quest, duty, contentArea)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent180");
	quest:StartSequence(SEQ_070);
	endMan0g1Content(player, duty, contentArea);
	GetWorldManager():DoZoneChange(player, 150, "PrivateAreaMasterPast", 0, 15, -770.197, 23, -1086.209, 0);
end

function failEscort(player, quest, duty, contentArea)
	quest:StartSequence(SEQ_060);
	player:SetHP(player:GetMaxHP());
	endMan0g1Content(player, duty, contentArea);
	GetWorldManager():DoZoneChange(player, 155, nil, 0, 15, -194.73, 3.54, -1021.33, -1.642);
end

function getJournalInformation(player, quest)
	local data = quest:GetData();
	return ENABLE_GL_TUTORIAL and 1 or 0, math.min(data:GetCounter(CNTR_SEQ15_LTW), 1) * 5, math.min(data:GetCounter(CNTR_SEQ15_CNJ), 3) * 5;
end

function getJournalMapMarkerList(player, quest)
    local sequence = quest:GetSequence();
	local data = quest:GetData();
    local possibleMarkers = {};

    if (sequence == SEQ_000) then
		table.insert(possibleMarkers, MRKR_MIOUNNE);
    elseif (sequence == SEQ_005) then
		table.insert(possibleMarkers, MRKR_BENTBRANCH);
	elseif (sequence == SEQ_010) then
		table.insert(possibleMarkers, MRKR_MIOUNNE2);
	elseif (sequence == SEQ_012) then
		table.insert(possibleMarkers, MRKR_MIOUNNE2);
	elseif (sequence == SEQ_015) then
		local subseqLTW = data:GetCounter(CNTR_SEQ15_LTW);
		local subseqCNJ = data:GetCounter(CNTR_SEQ15_CNJ);
		if (subseqLTW == 0) then
			table.insert(possibleMarkers, MRKR_HEREWARD);
		end
		if (subseqCNJ == 0) then
			table.insert(possibleMarkers, MRKR_SOILEINE);
		elseif (subseqCNJ == 1) then
			table.insert(possibleMarkers, MRKR_CNJ_TRIGGER);
		elseif (subseqCNJ == 2) then
			table.insert(possibleMarkers, MRKR_SWETHYNA);
		end
	elseif (sequence == SEQ_040) then
		table.insert(possibleMarkers, MRKR_OPYLTYL);
	elseif (sequence == SEQ_050) then
		table.insert(possibleMarkers, MRKR_KIDS_PRACTICE);
	elseif (sequence == SEQ_055) then
		table.insert(possibleMarkers, MRKR_KIDS_TRIGGER);
	elseif (sequence == SEQ_060) then
		table.insert(possibleMarkers, MRKR_GATE_TRIGGER);
	elseif (sequence == SEQ_065) then
		table.insert(possibleMarkers, MRKR_LIFEMEND_STUMP);
	elseif (sequence == SEQ_070) then
		table.insert(possibleMarkers, MRKR_STUMP_TRIGGER);
	elseif (sequence == SEQ_071) then
		table.insert(possibleMarkers, MRKR_STUMP_EXIT_TRIGGER);
	elseif (sequence == SEQ_072) then
		table.insert(possibleMarkers, MRKR_BTN_TRIGGER);
	elseif (sequence == SEQ_075) then

	elseif (sequence == SEQ_080) then
		table.insert(possibleMarkers, MRKR_WILLELDA);
	elseif (sequence == SEQ_085) then
		table.insert(possibleMarkers, MRKR_BURCHARD);
	elseif (sequence == SEQ_090) then
		table.insert(possibleMarkers, MRKR_BURCHARD2);
	elseif (sequence == SEQ_095) then
		table.insert(possibleMarkers, MRKR_NUALA);
	elseif (sequence == SEQ_100) then

	elseif (sequence == SEQ_105) then
		table.insert(possibleMarkers, MRKR_MIOUNNE3);
    end

    return unpack(possibleMarkers)
end
