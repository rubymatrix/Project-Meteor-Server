require("Global")
require("InstanceRaid")

--[[
The beastman aetheryte guides that open the Grand Company story raids, picked by the guide's zone:
the Howling Eye from Coerthas Central Highlands, the Castrum Novum beacon from Mor Dhona. Offered
while the talker is on the quest's raid step, in any company's version of it.
--]]

local TEXT_QUEST_REQUIREMENTS = 52048

local GC_GUIDES = {
	[143] = { raid = "lesser_garuda", quests = { 111430, 111630, 111830 }, seq = 10 },
	[190] = { raid = "beacon_battle", quests = { 111432, 111632, 111832 }, seq = 5 },
}

local function onRaidStep(player, guide)
	for _, id in ipairs(guide.quests) do
		local quest = player:GetQuest(id)
		if quest ~= nil and quest:GetSequence() == guide.seq then
			return true
		end
	end
	return false
end

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, eventType, eventName)
	local guide = GC_GUIDES[npc.CurrentArea.ZoneId]
	if guide == nil or (eventName ~= "talkDefault" and eventName ~= "pushCommand") then
		player:EndEvent()
		return
	end
	local def = getInstanceRaid(guide.raid)
	if not onRaidStep(player, guide) then
		player:SendGameMessage(GetWorldMaster(), TEXT_QUEST_REQUIREMENTS, 0x20, player, def.contentId)
		player:EndEvent()
		return
	end
	local yes = callClientFunction(player, "askEnterInstanceRaid", def.contentId)
	player:EndEvent()
	if yes == true or yes == 1 then
		enterInstanceRaid(guide.raid, player)
	end
end
