require("Global")
require("QuestFlow")
require("Quest/Man/Man2u0")

--[[
Calamity Cometh (Man2u0 SEQ_010): the minemite fight at the Nanawa Mines road (content
SimpleContentMan2u001, zone 170). The fight is Content/Quest/QuestDirectorMan2u001.lua.
Win: finishMinemiteFight (processEvent030, Seq 15). Loss: failMinemiteFight (back to the stables, 10).
Leaving or logging out keeps 10, so Rururaji stays armed.
--]]

function init()
	return "/Director/Quest/QuestDirectorMan2u001"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man2u0")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan2u001")
	if area == nil then
		return
	end

	local fight = StartContent("QuestDirectorMan2u001", "", area, player, { director = director, quest = quest })
	if fight == nil then
		return
	end
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
	end

	if player.CurrentArea ~= area then
		player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
		fight:Close()
		return
	end

	quest = player:GetQuest("Man2u0")
	if quest == nil or quest:GetSequence() ~= SEQ_010 then
		fight:Close()
		return
	end

	if fight.Result == "win" then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishMinemiteFight(player, quest, fight, area)
	else
		failMinemiteFight(player, quest, fight, area)
	end
end

function main()
end
