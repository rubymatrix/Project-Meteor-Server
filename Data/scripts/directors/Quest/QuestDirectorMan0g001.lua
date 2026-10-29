require ("global")
require ("modifiers")
require ("tutorial")
require ("quests/man/man0g0")

TEXT_RIGHT_OFF_WE_GO = 89;
WEAPONSKILL_TP       = 1000;
YDA_DISPLAY_ID       = 1100457;

function init()
	return "/Director/Quest/QuestDirectorMan0g001";
end

local function isBattleOver(player)
	local battle = GetContentFor(player);
	return battle == nil or battle.IsOver;
end

function onEventStarted(player, director, triggerName)
	local quest = player:GetQuest("Man0g0");
	if (quest == nil) then
		player:EndEvent();
		return;
	end

	startTutorialMode(player);
	local isWar = player:IsDiscipleOfWar();
	local isMagic = (not isWar) and player:IsDiscipleOfMagic();

	if (isWar) then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtl001");
		player:EndEvent();
		waitForSignal("playerActive");
		wait(1);
		kickEventContinue(player, director, "noticeEvent", "noticeEvent");
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtl002", nil, nil, nil);
		player:EndEvent();
		closeTutorialWidget(player);
		showTutorialSuccessWidget(player, 9055);
		openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_TP);
		while (not isBattleOver(player) and player:GetTP() < WEAPONSKILL_TP) do
			wait(0.5);
		end
		closeTutorialWidget(player);
		if (not isBattleOver(player)) then
			openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_WEAPONSKILLS);
			while (not isBattleOver(player) and player:GetTP() >= WEAPONSKILL_TP) do
				wait(0.5);
			end
			closeTutorialWidget(player);
			showTutorialSuccessWidget(player, 9065);
		end
	elseif (isMagic) then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtlMagic001");
		player:EndEvent();
		wait(1);
		closeTutorialWidget(player);
		openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_DEFEATENEMY);
		while (not isBattleOver(player)) do
			if (player:IsEngaged()) then
				player:SendGameMessageLocalizedDisplayName(quest, TEXT_RIGHT_OFF_WE_GO, MESSAGE_TYPE_SAY, YDA_DISPLAY_ID);
				break;
			end
			wait(1);
		end
	else
		player:EndEvent();
	end

	while (not isBattleOver(player)) do
		wait(1);
	end
	wait(3);
	closeTutorialWidget(player);
	if (isMagic) then
		showTutorialSuccessWidget(player, 9050);
	end

	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	if (player:GetHP() < player:GetMaxHP()) then
		player:SetHP(player:GetMaxHP());
	end
	player:SendDataPacket("attention", GetWorldMaster(), "", 51073, 2);
	wait(7);
	player:ChangeMusic(7);
	-- ChangeState alone leaves the player in active mode.
	player:Disengage(0);
	player:ChangeState(0);

	kickEventContinue(player, director, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020_1");
	quest:StartSequence(10);
	endTutorialMode(player);
	player:EndEvent();

	local battle = GetContentFor(player);
	if (battle ~= nil) then
		battle:Close();
	end
	player.CurrentArea:ContentFinished();
	GetWorldManager():DoZoneChange(player, 155, "PrivateAreaMasterPast", 1, 15, 175.38, -1.21, -1156.51, -2.1);
end

function main()
end
