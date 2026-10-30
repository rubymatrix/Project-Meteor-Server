require("Global")
require("Modifiers")
require("Tutorial")
require("Quest/Man/Man0u0")

--[[
Flowers for All (Man0u0) tutorial skirmish: battle tutorial widgets for Disciples of War or Magic,
then hands back to the quest's finishSkirmish once the fight is over.
--]]

local WEAPONSKILL_TP = 1000

function init()
	return "/Director/Quest/QuestDirectorMan0u001"
end

local function isBattleOver(player)
	local battle = GetContentFor(player)
	return battle == nil or battle.IsOver
end

function onEventStarted(player, director, triggerName)
	local quest = player:GetQuest("Man0u0")
	if quest == nil then
		player:EndEvent()
		return
	end

	startTutorialMode(player)
	local isWar = player:IsDiscipleOfWar()
	local isMagic = (not isWar) and player:IsDiscipleOfMagic()

	if isWar then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtl001")
		player:EndEvent()
		waitForSignal("playerActive")
		wait(1)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtl002", nil, nil, nil)
		player:EndEvent()
		closeTutorialWidget(player)
		showTutorialSuccessWidget(player, 9055)
		openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_TP)
		while not isBattleOver(player) and player:GetTP() < WEAPONSKILL_TP do
			wait(0.5)
		end
		closeTutorialWidget(player)
		if not isBattleOver(player) then
			openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_WEAPONSKILLS)
			while not isBattleOver(player) and player:GetTP() >= WEAPONSKILL_TP do
				wait(0.5)
			end
			closeTutorialWidget(player)
			showTutorialSuccessWidget(player, 9065)
		end
	elseif isMagic then
		callClientFunction(player, "delegateEvent", player, quest, "processTtrBtlMagic001")
		player:EndEvent()
		wait(1)
		closeTutorialWidget(player)
		openTutorialWidget(player, CONTROLLER_KEYBOARD, TUTORIAL_DEFEATENEMY)
	else
		player:EndEvent()
	end

	while not isBattleOver(player) do
		wait(1)
	end
	wait(3)
	closeTutorialWidget(player)
	if isMagic then
		showTutorialSuccessWidget(player, 9050)
	end

	player:SetMod(Modifier.MinimumHpLock, 0)
	if player:GetHP() < player:GetMaxHP() then
		player:SetHP(player:GetMaxHP())
	end
	player:SendDataPacket("attention", GetWorldMaster(), "", 51073, 3)
	wait(7)
	player:ChangeMusic(7)
	-- ChangeState alone leaves the player in active mode.
	player:Disengage(0)
	player:ChangeState(0)

	kickEventContinue(player, director, "noticeEvent", "noticeEvent")
	quest = player:GetQuest("Man0u0")
	if quest == nil or quest:GetSequence() ~= SEQ_005 then
		endTutorialMode(player)
		player:EndEvent()
		return
	end
	finishSkirmish(player, quest, GetContentFor(player), player.CurrentArea)
end

function main()
end
