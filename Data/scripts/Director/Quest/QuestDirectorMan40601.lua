require("Global")
require("QuestFlow")
require("Quest/Man/Man406")

--[[
Futures Perfect (Man406), Mor Dhona. SimpleContentMan40602 (Seq 15) is the field duty, fought in
Content/Quest/QuestDirectorMan40601.lua; SimpleContentMan40603 (Seq 20) is the cave, no fight.
The ambush (processEvent025) plays on a fresh notice at the end of the track and opens the fight.
A knockout, the clock or straying fails it and the quest stays at 15.
--]]

local caveWatch, runField

function init()
	return "/Director/Quest/QuestDirectorMan40601"
end

function onEventStarted(player, director, triggerName)
	local area = player.CurrentArea
	if area ~= nil and area:GetPrivateAreaName() == "SimpleContentMan40603" then
		player:EndEvent()
		caveWatch(player, area)
		return
	end
	player:EndEvent()
	runField(player, director)
end

function caveWatch(player, area)
	player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	local quest = player:GetQuest("Man406")
	if quest ~= nil then
		quest:UpdateENPCs()
	end
	while player.CurrentArea == area do
		wait(2)
	end
	pcall(function() area:ContentFinished() end)
end

-- MAN40625 on a fresh notice; the fight opens when it closes.
local function playAmbush(player, director, quest, fight)
	kickEventContinue(player, director, "noticeEvent", "noticeEvent")
	delegateEvent(player, quest, "processEvent025")
	player:EndEvent()
	setQuestFlagOn(quest, FLAG_AMBUSH_SEEN)
	fight:GotoPhase("fight")
end

function runField(player, director)
	local quest = player:GetQuest("Man406")
	if quest == nil or quest:GetSequence() ~= SEQ_015 then
		return
	end
	local area = waitForContentArea(player, "SimpleContentMan40602")
	if area == nil then
		return
	end
	-- A failed run leaves the ambush flag behind; the camp scene flag is kept.
	clearQuestFlag(quest, FLAG_AMBUSH_SEEN)
	quest:UpdateENPCs()

	local fight = StartContent("QuestDirectorMan40601", "", area, player, { director = director })
	if fight == nil then
		return
	end
	if fight:Group("centurion").Count == 0 then
		fight:Close()
		return
	end

	local ambushed = false
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
		if not ambushed and fight:Counter("ambush") > 0 then
			ambushed = true
			playAmbush(player, director, quest, fight)
		end
	end

	if player.CurrentArea ~= area then
		fight:Close()
		pcall(function() area:ContentFinished() end)
		return
	end

	quest = player:GetQuest("Man406")
	if quest == nil or quest:GetSequence() ~= SEQ_015 then
		fight:Close()
		return
	end

	if fight.Result == "win" then
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishField(player, quest, fight, area)
	else
		if fight.Reason ~= "time" and fight.Reason ~= "left" then
			wait(3)
		end
		failField(player, quest, fight, area)
	end
end

function main()
end
