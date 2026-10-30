require("Global")
require("QuestFlow")
require("Quest/Man/Man402")

--[[
Of Men They Sing (Man402) Seq 5: the search (content SimpleContentMan40201, East Shroud 151).
The fight is Content/Quest/QuestDirectorMan40201.lua; this side plays the quest's part:
 - The companion's lines: "guard her" on arrival, then at the first and the second kill. The second
   kill sets FLAG_HOUNDS_DEFEATED, and a talk to the scout after it wins at once.
 - A knockout, the clock or leaving fails; the quest stays at 5.
Win: finishSearch (pE20, Seq 15). Loss: failSearch.
Her lines are man402 text rows by personality position (Say, the client fills in her name).
--]]

local TEXT_GUARD_HER = 222 -- + personality position - 1
local TEXT_WRAPPED_ABOUT = 231
local TEXT_RINGS_FASTENED = 240

-- Nine-row packs by personality position: the Roegadyn male (7) reads 8 and the Miqo'te female (8) 7.
local function packPosition(player)
	local personality = math.max(1, math.min(9, player:GetSNpcPersonality() or 1))
	if personality == 7 then
		return 8
	elseif personality == 8 then
		return 7
	end
	return personality
end

local function companionSay(player, quest, fight, area, base)
	local list = fight:Group("companion")
	local companion = list.Count > 0 and list[0] or area:FindActorInZoneByUniqueID("man402_companion")
	if companion ~= nil then
		player:SendGameMessage(companion, quest, base + packPosition(player) - 1, MESSAGE_TYPE_SAY)
	end
end

function init()
	return "/Director/Quest/QuestDirectorMan40201"
end

function onEventStarted(player, director, triggerName)
	player:EndEvent()
	local quest = player:GetQuest("Man402")
	if quest == nil or quest:GetSequence() ~= SEQ_005 then
		return
	end

	local area = waitForContentArea(player, "SimpleContentMan40201")
	if area == nil then
		return
	end
	-- A failed run leaves the kill flag behind; the camp scene flag is kept.
	clearQuestFlag(quest, FLAG_HOUNDS_DEFEATED)
	quest:UpdateENPCs()

	local fight = StartContent("QuestDirectorMan40201", "", area, player, { director = director })
	if fight == nil then
		return
	end
	local arrived, kills = false, 0
	while fight.IsRunning and player.CurrentArea == area do
		local scoutSafe = waitForPlayerSignal(player, "man402ScoutSafe", 1)
		if not arrived and fight:Counter("arrived") > 0 then
			arrived = true
			companionSay(player, quest, fight, area, TEXT_GUARD_HER)
		end
		local nowKills = fight:Counter("kills")
		if kills < 1 and nowKills >= 1 then
			companionSay(player, quest, fight, area, TEXT_WRAPPED_ABOUT)
		end
		if kills < 2 and nowKills >= 2 then
			companionSay(player, quest, fight, area, TEXT_RINGS_FASTENED)
			setQuestFlagOn(quest, FLAG_HOUNDS_DEFEATED)
		end
		kills = nowKills
		if scoutSafe and kills >= 2 and fight.IsRunning then
			fight:Win("scout")
		end
	end

	if player.CurrentArea ~= area then
		fight:Close()
		pcall(function() area:ContentFinished() end)
		return
	end

	quest = player:GetQuest("Man402")
	if quest == nil or quest:GetSequence() ~= SEQ_005 then
		fight:Close()
		return
	end

	if fight.Result == "win" then
		kickEventContinue(player, director, "noticeEvent", "noticeEvent")
		finishSearch(player, quest, fight, area)
	else
		if fight.Reason ~= "time" and fight.Reason ~= "left" then
			wait(3)
		end
		failSearch(player, quest, fight, area)
	end
end

function main()
end
