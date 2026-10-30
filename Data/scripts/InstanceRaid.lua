require("Global")
require("Utils")

--[[
The instance raids the Grand Company story quests send the player into.

getInstanceRaid(key) gives the raid's client contentId and the content that runs it.
enterInstanceRaid(key, player) takes the player and the party members standing near into a new copy
of the raid and returns its content, or nil when the party is too big or the copy can't be made.
On a win the content calls each participant's quest onRaidCleared(player, quest, director, bonus)
(Content/InstanceRaid/StoryRaid.lua).
--]]

local TEXT_PARTY_REQUIREMENTS = 52039
local GATE_RANGE = 30

local INSTANCE_RAIDS = {
	lesserIfrit = { contentId = 4, content = "InstanceRaidLesserIfrit", minLevel = 25, partySize = 4 },
	lesserGaruda = { contentId = 12, content = "InstanceRaidLesserGaruda", minLevel = 40, partySize = 8 },
	beaconBattle = { contentId = 13, content = "InstanceRaidBeaconBattle", minLevel = 45, partySize = 8 },
	lesserWhiteGeneral = { contentId = 15, content = "InstanceRaidLesserWhiteGeneral", minLevel = 45, partySize = 8 },
}

function getInstanceRaid(key)
	return INSTANCE_RAIDS[key]
end

-- The party members on this server, in the player's area and near them.
local function nearbyParty(player)
	local list = {}
	local party = player.currentParty
	if party == nil or party.members == nil then return list end
	for id in party.members do
		if id ~= player.Id then
			local member = GetWorldManager():GetPCInWorld(id)
			if member ~= nil and member.CurrentArea == player.CurrentArea
				and getDistanceBetweenActors(player, member) <= GATE_RANGE then
				table.insert(list, member)
			end
		end
	end
	return list
end

function enterInstanceRaid(key, player)
	local raid = INSTANCE_RAIDS[key]
	if raid == nil or player == nil then return nil end
	local party = nearbyParty(player)
	if #party + 1 > raid.partySize then
		player:SendGameMessage(GetWorldMaster(), TEXT_PARTY_REQUIREMENTS, 0x20, raid.contentId, raid.minLevel, raid.partySize)
		for _, member in ipairs(party) do
			member:SendGameMessage(GetWorldMaster(), TEXT_PARTY_REQUIREMENTS, 0x20, raid.contentId, raid.minLevel, raid.partySize)
		end
		return nil
	end
	return StartContent(raid.content, "", nil, player, { participants = party })
end
