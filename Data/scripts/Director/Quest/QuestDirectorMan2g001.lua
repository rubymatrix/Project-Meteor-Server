require("Global")
require("QuestFlow")
require("Quest/Man/Man2g0")

--[[
Beckon of the Elementals (Man2g0 SEQ_004): the spirit of the wood (SimpleContentMan2g001, zone 153).
The fight is Content/Quest/QuestDirectorMan2g001.lua; O-App-Pesi's ward (Man2g0 wardTalk) moves it
to the element's phase. Win: finishSpirit (Seq 5). Loss, leaving or logging out keeps Seq 4, so
the ask stays armed.
--]]

function init()
	return "/Director/Quest/QuestDirectorMan2g001"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man2g0")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, DUTY_CONTENT)
	if area == nil then
		return
	end

	local fight = StartContent("QuestDirectorMan2g001", "", area, player, { director = director, quest = quest })
	if fight == nil then
		return
	end
	local ward = 0
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
		local picked = getQuestCounter(quest, CNTR_WARD)
		if picked ~= ward and picked >= 1 and picked <= 3 then
			ward = picked
			fight:GotoPhase("ward" .. ward)
		end
	end

	if player.CurrentArea ~= area then
		player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
		fight:Close()
		return
	end

	quest = player:GetQuest("Man2g0")
	if quest == nil or quest:GetSequence() ~= SEQ_004 then
		fight:Close()
		return
	end

	if fight.Result == "win" then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishSpirit(player, quest, fight, area)
	else
		wait(3)
		failSpirit(player, quest, fight, area)
	end
end

function main()
end
