require("Global")
require("QuestFlow")
require("Quest/Man/Man300")

--[[
Toll of the Warden (Man300 SEQ_025/030): the excavation mesa (content SimpleContentMan30001, zone 171).
The fight is Content/Quest/QuestDirectorMan30001.lua; this side plays the quest's part:
 - On landing at 25 Nananoby's briefing plays (pE40) and the step moves to 30.
 - The fighters' lines as they engage and give up. Both fighters of a tribe beaten settles that tribe,
   as does a Parley won with its shaman (Man300 onParleyEnd), which stands the tribe down in the fight.
 - Both tribes settled: SETTLE_DELAY seconds later pE50 and out to the mesa (finishMesaDuty).
 - A knockout or the time running out loses the run (failMesaDuty: back to 20).
 - The companion (an event actor of the player's class) walks with the player.
--]]

local SETTLE_DELAY = 15
local COMPANION_FOLLOW = 5.0

-- Per fighter, in the fight's order: the line as it engages and as it gives up.
local FIGHTER_LINES = {
	{ engage = 524, withdraw = 530 },
	{ engage = 525, withdraw = 531 },
	{ engage = 521, withdraw = 527 },
	{ engage = 522, withdraw = 528 },
}

local TRIBES = {
	{ flag = FLAG_IXAL_DONE, counter = "ixal", phase = "ixalSettled" },
	{ flag = FLAG_AMALJAA_DONE, counter = "amaljaa", phase = "amaljaaSettled" },
}

local function dist2(a, b)
	return math.sqrt((a.positionX - b.positionX) ^ 2 + (a.positionZ - b.positionZ) ^ 2)
end

local function fighter(fight, i)
	local list = fight:Group("fighter" .. i)
	return list.Count > 0 and list[0] or nil
end

-- The fighters' lines for what the fight reports since the last call.
local function sayLines(player, quest, fight, said)
	for i, lines in ipairs(FIGHTER_LINES) do
		local mob = fighter(fight, i)
		if mob ~= nil then
			if not said["engaged" .. i] and fight:Counter("engaged" .. i) > 0 then
				said["engaged" .. i] = true
				player:SendGameMessage(mob, quest, lines.engage, MESSAGE_TYPE_SAY)
			end
			if not said["withdrawn" .. i] and fight:Counter("withdrawn" .. i) > 0 then
				said["withdrawn" .. i] = true
				player:SendGameMessage(mob, quest, lines.withdraw, MESSAGE_TYPE_SAY)
			end
		end
	end
end

-- A tribe beaten down sets its flag; a tribe flagged by Parley stands down in the fight.
local function settleTribes(quest, fight, settled)
	for _, t in ipairs(TRIBES) do
		if not settled[t.counter] then
			if fight:Counter(t.counter) >= 2 then
				settled[t.counter] = true
				setQuestFlagOn(quest, t.flag)
			elseif getQuestFlag(quest, t.flag) then
				settled[t.counter] = true
				fight:GotoPhase(t.phase)
			end
		end
	end
end

function init()
	return "/Director/Quest/QuestDirectorMan30001"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man300")
	if quest == nil then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan30001")
	if area == nil then
		return
	end

	local fight = StartContent("QuestDirectorMan30001", "", area, player, { director = director })
	if fight == nil then
		return
	end
	local companion = area:FindActorInZoneByUniqueID("man300_companion")

	if quest:GetSequence() == SEQ_025 and not getQuestFlag(quest, FLAG_BRIEFING) then
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		quest = player:GetQuest("Man300")
		if quest == nil then
			player:EndEvent()
			fight:Close()
			return
		end
		playBriefing(player, quest)
	end

	local said, settled = {}, {}
	local settledAt = nil
	local elapsed = 0
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
		elapsed = elapsed + 1
		quest = player:GetQuest("Man300")
		if quest == nil then
			break
		end

		sayLines(player, quest, fight, said)
		settleTribes(quest, fight, settled)

		if companion ~= nil and dist2(companion, player) > COMPANION_FOLLOW then
			companion:FollowTarget(player, 1.2, 25, COMPANION_FOLLOW - 1)
		end

		if quest:GetSequence() == SEQ_030 and getQuestFlag(quest, FLAG_IXAL_DONE) and getQuestFlag(quest, FLAG_AMALJAA_DONE) then
			settledAt = settledAt or elapsed
			if elapsed - settledAt >= SETTLE_DELAY then
				fight:Win("settled")
			end
		end
	end

	if player.CurrentArea ~= area then
		fight:Close()
		return -- left or logged out: the mesa asks again
	end
	quest = player:GetQuest("Man300")
	if quest == nil then
		fight:Close()
		return
	end

	-- !content win ends the fight as won too.
	if fight.Result == "win" then
		wait(2)
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		quest = player:GetQuest("Man300")
		if quest == nil then
			player:EndEvent()
			fight:Close()
			return
		end
		if quest:GetSequence() == SEQ_025 then
			quest:StartSequence(SEQ_030)
		end
		finishMesaDuty(player, quest, fight, area)
	else
		if fight.IsRunning then
			fight:Fail("script")
		end
		wait(3)
		failMesaDuty(player, quest, fight, area)
	end
end

function main()
end
