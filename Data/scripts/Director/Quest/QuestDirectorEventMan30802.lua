require("Global")
require("QuestFlow")
require("Quest/Man/Man308")

--[[
Lord Errant (Man308) SEQ_015: the quest's side of the Bowl of Embers (SimpleContentMan30803, zone 240).
The fight is Content/Quest/QuestDirectorEventMan30802.lua; this records captives settled and plays
the landing scenes. Details: Data/Docs/Scripts/Director/Quest/QuestDirectorEventMan30802.md.
--]]

local CAPTIVE_FLAGS = { FLAG_MAID_SETTLED, FLAG_ELEZEN_SETTLED, FLAG_MIDLANDER_SETTLED }

local function recordProgress(quest, fight, recorded)
	for i, flag in ipairs(CAPTIVE_FLAGS) do
		if not recorded[i] and fight:Counter("captive" .. i) > 0 then
			recorded[i] = true
			setQuestFlagOn(quest, flag)
			setQuestCounter(quest, CNTR_CAPTIVES_SUBDUED, fight:Counter("subdued"))
		end
	end
	if not recorded.stopped and fight:Counter("stopped") > 0 then
		recorded.stopped = true
		setQuestFlagOn(quest, FLAG_CAPTIVES_STOPPED)
	end
end

function init()
	return "/Director/Quest/QuestDirectorEventMan30802"
end

function onEventStarted(player, director, triggerName)
	local quest = player:GetQuest("Man308")
	if quest == nil or quest:GetSequence() ~= SEQ_015 then
		player:EndEvent()
		return
	end

	-- The summoning and the turning play on the landing; a relaunch after a loss skips them.
	if not getQuestFlag(quest, FLAG_RITUAL_SEEN) then
		companionEvent(player, quest, "pE50", true)
		companionEvent(player, quest, "pE60")
		setQuestFlagOn(quest, FLAG_RITUAL_SEEN)
	end
	player:EndEvent()
	quest:UpdateENPCs()

	local area = waitForContentArea(player, "SimpleContentMan30803")
	if area == nil then
		return
	end

	-- The duty restarts whole.
	for _, flag in ipairs(CAPTIVE_FLAGS) do
		clearQuestFlag(quest, flag)
	end
	clearQuestFlag(quest, FLAG_CAPTIVES_STOPPED)
	setQuestCounter(quest, CNTR_CAPTIVES_SUBDUED, 0)

	local fight = StartContent("QuestDirectorEventMan30802", "", area, player, { director = director })
	if fight == nil then
		return
	end
	local recorded = {}
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
		recordProgress(quest, fight, recorded)
	end

	if player.CurrentArea ~= area then
		fight:Close()
		pcall(function() area:ContentFinished() end)
		return
	end

	quest = player:GetQuest("Man308")
	if quest == nil or quest:GetSequence() ~= SEQ_015 then
		fight:Close()
		return
	end

	if fight.Result == "win" then
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishBowl(player, quest, fight, area)
	else
		wait(3)
		failBowl(player, quest, fight, area)
	end
end

function main()
end
