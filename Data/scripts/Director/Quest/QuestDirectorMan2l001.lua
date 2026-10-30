require("Global")
require("QuestFlow")
require("Quest/Man/Man2l0")

--[[
Never the Twain Shall Meet (Man2l0 SEQ_020): the deck duel (content SimpleContentMan2l001, zone 192).
The fight is Content/Quest/QuestDirectorMan2l001.lua.
Win: finishDeckDuel (processEvent020 with the winner, SEQ_035, the Limsa docks). Loss: failDeckDuel,
back on the dromond at 20. Leaving the area ends the duel and 20 keeps the boarding routes armed.
--]]

function init()
	return "/Director/Quest/QuestDirectorMan2l001"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man2l0")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan2l001")
	if area == nil then
		return
	end

	local fight = StartContent("QuestDirectorMan2l001", "", area, player, { director = director })
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

	quest = player:GetQuest("Man2l0")
	if quest == nil or quest:GetSequence() ~= SEQ_020 then
		fight:Close()
		return
	end

	local winner = fight:Counter("winner")
	if fight.Result == "win" and winner > 0 then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishDeckDuel(player, quest, fight, area, winner)
	else
		failDeckDuel(player, quest, fight, area)
	end
end

function main()
end
