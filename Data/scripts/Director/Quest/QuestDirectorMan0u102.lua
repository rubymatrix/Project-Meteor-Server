require("Global")
require("Modifiers")
require("Quest/Man/Man0u1")

--[[
Quest side of the Man0u1 escort: starts the escort (Content/Quest/QuestDirectorMan0u102.lua) and
waits for its outcome.
--]]

local waitForContentArea

function init()
	return "/Director/Quest/QuestDirectorMan0u102"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man0u1")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan0u102")
	if area == nil then
		return
	end

	local escort = StartContent("QuestDirectorMan0u102", "", area, player, { director = director, quest = quest })
	if escort == nil then
		return
	end
	while escort.IsRunning and player.CurrentArea == area do
		wait(1)
	end

	if player.CurrentArea ~= area then
		player:SetMod(Modifier.MinimumHpLock, 0)
		escort:Close()
		return
	end

	quest = player:GetQuest("Man0u1")
	if quest == nil or quest:GetSequence() ~= SEQ_065 then
		escort:Close()
		return
	end

	if escort.Result == "win" then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishEscort(player, quest, escort, area)
	else
		wait(3)
		failEscort(player, quest, escort, area)
	end
end

function main()
end

function waitForContentArea(player, contentName)
	for i = 1, 20 do
		local area = player.CurrentArea
		if area ~= nil and area:GetPrivateAreaName() == contentName then
			return area
		end
		wait(0.5)
	end
	return nil
end
