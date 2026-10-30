--[[
Shared helpers for the Grand Company story quests (gcl101, gcl104-gcl107). Not a quest script:
the Gcl10x scripts require it.

The client loads one Gcl class per company for each of these quests (ids 1114xx Maelstrom, 1116xx Twin
Adder, 1118xx Immortal Flames), so the three ids share one server script. The shared client functions
take the company as an argument (1, 2, 3); the officer and city scenes are separate functions per company.
--]]

GC_MAELSTROM	= 1
GC_TWINADDER	= 2
GC_FLAMES		= 3

-- Company officers (PopulaceCompanyOfficer), one per headquarters.
GC_GUINCUM		= 1500199
GC_FULKE		= 1500200
GC_AUBREY		= 1500198

-- The city halls where the leaders receive the player: guide, leader, marshal.
GC_ZANTHAEL		= 1000351
GC_MERLWYB		= 1001568
GC_EYNZAHR		= 1060024
GC_MUMUTANO		= 1001423
GC_RAUBAHN		= 1002051
GC_ELINE		= 1060026
GC_KINNISON		= 1001430
GC_KANESENNA	= 1001569
GC_BROOKSTONE	= 1060025

-- The staged private areas: arrival point, and where the exit push (or the end of the quest)
-- puts the player back.
GC_HALLS = {
	lotus = {
		zone = 206, pa = 61, exitPush = 1090351,
		arrival = {-330.83, 8.0, -1682.79, -2.4},
		back = {-190.0, 22.95, -1606.0, 2.2},
	},
	stateroom = {
		zone = 133, pa = 61, exitPush = 1090352,
		arrival = {-441.0, 21.0, 175.0, -2.4},
		back = {-438.0, 21.0, 179.0, 0.8},
	},
	chamber = {
		zone = 209, pa = 61, exitPush = 1090353,
		arrival = {-122.0, 226.0, 244.0, -2.4},
		back = {-119.0, 226.0, 248.0, 0.8},
	},
}

-- The client's function suffixes name the company's city: Lim/L, Gri/G, Uld/U/Uru.
GC_COMPANY = {
	[GC_MAELSTROM] = {
		officer = GC_GUINCUM, officerName = "Guincum", hqZone = 232, city = "Lim", letter = "L",
		hall = "stateroom", hallGuide = GC_ZANTHAEL, leader = GC_MERLWYB, marshal = GC_EYNZAHR,
	},
	[GC_TWINADDER] = {
		officer = GC_FULKE, officerName = "Fulke", hqZone = 234, city = "Gri", letter = "G",
		hall = "lotus", hallGuide = GC_KINNISON, leader = GC_KANESENNA, marshal = GC_BROOKSTONE,
	},
	[GC_FLAMES] = {
		officer = GC_AUBREY, officerName = "Aubrey", hqZone = 233, city = "Uld", letter = "U",
		hall = "chamber", hallGuide = GC_MUMUTANO, leader = GC_RAUBAHN, marshal = GC_ELINE,
	},
}

function gcCompanyOfQuestId(questId)
	local block = math.floor(questId / 100)
	if block == 1114 then
		return GC_MAELSTROM
	elseif block == 1116 then
		return GC_TWINADDER
	elseif block == 1118 then
		return GC_FLAMES
	end
	return nil
end

function gcCompany(quest)
	local id = gcCompanyOfQuestId(quest:GetQuestId())
	if id == nil then
		return nil, nil
	end
	return id, GC_COMPANY[id]
end

local function gcQuestIds(suffix)
	return { 111400 + suffix, 111600 + suffix, 111800 + suffix }
end

local function gcHeldQuest(player, suffix)
	for _, id in ipairs(gcQuestIds(suffix)) do
		local q = player:GetQuest(id)
		if q ~= nil then
			return q
		end
	end
	return nil
end

-- Both run after the event has ended.
function gcEnterHall(player, hallKey)
	local h = GC_HALLS[hallKey]
	local a = h.arrival
	GetWorldManager():DoZoneChange(player, h.zone, "PrivateAreaMasterPast", h.pa, 15, a[1], a[2], a[3], a[4])
end

function gcLeaveHall(player, hallKey)
	local h = GC_HALLS[hallKey]
	local r = h.back
	GetWorldManager():DoZoneChange(player, h.zone, nil, 0, 15, r[1], r[2], r[3], r[4])
end

function gcHallOfExit(classId)
	for key, h in pairs(GC_HALLS) do
		if h.exitPush == classId then
			return key
		end
	end
	return nil
end

function gcHallOfPlayer(player)
	local area = player.CurrentArea
	if area == nil or not area:IsPrivate() then
		return nil
	end
	for key, h in pairs(GC_HALLS) do
		if area.ZoneId == h.zone then
			return key
		end
	end
	return nil
end
