require("Global")
require("Modifiers")
require("Quest/Man/Man0u1")

local waitForContentArea

function init()
	return "/Director/Quest/QuestDirectorMan0u101"
end

-- The match itself is Content/Quest/QuestDirectorMan0u101.lua. Every ending is a loss.
function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man0u1")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan0u101")
	if area == nil then
		return
	end

	local match = StartContent("QuestDirectorMan0u101", "", area, player, { director = director, quest = quest })
	if match == nil then
		return
	end
	while match.IsRunning and player.CurrentArea == area do
		wait(1)
	end

	if player.CurrentArea ~= area then
		player:SetMod(Modifier.MinimumHpLock, 0)
		match:Close()
		return
	end

	-- The client's own KO handling sends this line, and a pinned loss never reaches it.
	player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "You are defeated.")
	player:SetHP(player:GetMaxHP())
	player:Disengage(0)
	player:ChangeState(0)
	wait(2)
	kickEventContinue(player, director, "noticeEvent", "noticeEvent")
	quest = player:GetQuest("Man0u1")
	if quest == nil or quest:GetSequence() ~= SEQ_015 then
		player:SetMod(Modifier.MinimumHpLock, 0)
		player:EndEvent()
		match:Close()
		return
	end
	finishColiseumMatch(player, quest, match, area)
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
