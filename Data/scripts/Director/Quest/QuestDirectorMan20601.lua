require("Global")
require("QuestFlow")
require("Quest/Man/Man206")

--[[
Together We Stand (Man206 SEQ_020/025): the stealth run through Moonspore Grove (content
SimpleContentMan20601, zone 151). The fight is Content/Quest/QuestDirectorMan20601.lua; this side plays
the quest's part:
 - Cover: a sylph's talk (CNTR_CONCEAL), the grove scene and the pickup each move the fight to "cover".
 - The sentries' lines as they spot the player and close in. The companion's opening line after
   OPENING_LINE_SECONDS and its one warning when a sentry is near.
 - Hand-overs on approach (HANDOFF_RANGE): the grove's mouth plays processEvent016, Dokixia the pickup
   (after the scene), Flaxio the delivery (carrying), which wins the run. Their talks do the same.
 - A lost run (time up, the companion left behind) returns the step to 15 at the camp.
--]]

local OPENING_LINE_SECONDS = 5
local HANDOFF_RANGE = 8.0

local TEXT_HALT = 537
local TEXT_ENEMIES_SIGHTED = 538
local TEXT_OPENING_BASE = 542 -- + personality - 1
local TEXT_NOTICE_BASE = 560

local SENTRY_COUNT = 7
local GROVE_SCENE_POINT = { 1927.550, -1058.200 }
local DOKIXIA_POINT = { 2239.857, -1697.957 }
local FLAXIO_POINT = { 1979.560, -1067.752 }

local function near(player, point, radius)
	return math.sqrt((player.positionX - point[1]) ^ 2 + (player.positionZ - point[2]) ^ 2) <= radius
end

local function sentry(fight, i)
	local list = fight:Group("sentry" .. i)
	return list.Count > 0 and list[0] or nil
end

-- One line per new sighting or halt the fight reports.
local function sentryLines(player, quest, fight, seen)
	for i = 1, SENTRY_COUNT do
		local mob = sentry(fight, i)
		if mob ~= nil then
			for _, kind in ipairs({ "sighted", "halted" }) do
				local key = kind .. i
				local n = fight:Counter(key)
				if n > (seen[key] or 0) then
					seen[key] = n
					local textId = kind == "sighted" and TEXT_ENEMIES_SIGHTED or TEXT_HALT
					player:SendGameMessage(mob, quest, textId, MESSAGE_TYPE_SAY)
				end
			end
		end
	end
end

function init()
	return "/Director/Quest/QuestDirectorMan20601"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man206")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan20601")
	if area == nil then
		return
	end

	local fight = StartContent("QuestDirectorMan20601", "", area, player, { director = director, quest = quest })
	if fight == nil then
		return
	end
	local companion = area:FindActorInZoneByUniqueID("man206_companion")

	local personality = companionPersonality(player)
	local elapsed = 0
	local lastConceal = getQuestCounter(quest, CNTR_CONCEAL)
	local groveCover, carryCover = false, false
	local openingSaid, noticeSaid = false, false
	local seen = {}

	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
		elapsed = elapsed + 1
		quest = player:GetQuest("Man206")
		if quest == nil then
			break
		end
		local sequence = quest:GetSequence()
		if sequence ~= SEQ_020 and sequence ~= SEQ_025 then
			return -- delivered: the quest took the player out
		end

		local takeCover = false
		local request = getQuestCounter(quest, CNTR_CONCEAL)
		if request ~= lastConceal then
			lastConceal = request
			takeCover = true
		end
		if not groveCover and getQuestFlag(quest, FLAG_GROVE_SCENE) then
			groveCover = true
			takeCover = true
		end
		if not carryCover and getQuestFlag(quest, FLAG_CARRYING_PODLING) then
			carryCover = true
			takeCover = true
		end
		if takeCover then
			fight:GotoPhase("cover")
		end

		sentryLines(player, quest, fight, seen)
		if companion ~= nil then
			if not openingSaid and elapsed >= OPENING_LINE_SECONDS then
				openingSaid = true
				player:SendGameMessage(companion, quest, TEXT_OPENING_BASE + personality - 1, MESSAGE_TYPE_SAY)
			end
			if not noticeSaid and fight:Counter("sentryNear") > 0 then
				noticeSaid = true
				player:SendGameMessage(companion, quest, TEXT_NOTICE_BASE + personality - 1, MESSAGE_TYPE_SAY)
			end
		end

		-- Each hand-over runs in the kicked notice.
		if sequence == SEQ_025 and getQuestFlag(quest, FLAG_CARRYING_PODLING) and near(player, FLAXIO_POINT, HANDOFF_RANGE) then
			kickEventContinue(player, director, "noticeEvent", "noticeEvent")
			quest = player:GetQuest("Man206")
			if quest ~= nil and quest:GetSequence() == SEQ_025 then
				deliverPodling(player, quest, fight, area)
			else
				player:EndEvent()
			end
			return
		elseif sequence == SEQ_020 and getQuestFlag(quest, FLAG_GROVE_SCENE) and near(player, DOKIXIA_POINT, HANDOFF_RANGE) then
			kickEventContinue(player, director, "noticeEvent", "noticeEvent")
			quest = player:GetQuest("Man206")
			if quest ~= nil and quest:GetSequence() == SEQ_020 then
				takePodling(player, quest)
			else
				player:EndEvent()
			end
		elseif sequence == SEQ_020 and not getQuestFlag(quest, FLAG_GROVE_SCENE) and near(player, GROVE_SCENE_POINT, HANDOFF_RANGE) then
			kickEventContinue(player, director, "noticeEvent", "noticeEvent")
			quest = player:GetQuest("Man206")
			if quest ~= nil then
				playGroveScene(player, quest)
			else
				player:EndEvent()
			end
		end
	end

	if player.CurrentArea ~= area then
		-- Left or logged out: the camp trigger asks again at 20/25.
		player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
		fight:Close()
		return
	end

	quest = player:GetQuest("Man206")
	if quest == nil then
		fight:Close()
		return
	end
	local sequence = quest:GetSequence()
	if sequence ~= SEQ_020 and sequence ~= SEQ_025 then
		return
	end
	if fight.Result ~= "win" then
		wait(2)
		failGroveDuty(player, quest, fight, area)
	end
end

function main()
end
