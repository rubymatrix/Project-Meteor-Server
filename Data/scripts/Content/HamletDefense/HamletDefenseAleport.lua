--[[
Hamlet Defense at Aleport, the combat stage of the HamletAleport campaign: kobold waves march on four
supply caches past the militia. Won by killing the leader or holding every wave; lost when every cache
falls. Positions stand in near Camp Bald Knoll, and the area borrows an occupancy director.
--]]

local Hamlet = ContentArea.define("HamletDefenseAleport")

Hamlet.area = {
	zone = 129,
	classPath = "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent",
	name = "hamletDefenseAleport",
	script = "SimpleContentOccupancy",
	director = "Occupancy/RaidRoc0Dungeon01",
}
Hamlet.entry = { -1883.0, 53.8, -1360.0, 0 }

local POOL_RAIDER, POOL_LEADER, POOL_GUARD, POOL_CACHE = 9300003, 9300004, 9300005, 9300006
local TIME_LIMIT = 25 * 60

local CACHES = {
	{ -1851.4, 53.8, -1380.4 }, { -1839.2, 50.8, -1369.7 }, { -1874.0, 56.1, -1423.8 }, { -1897.2, 53.5, -1412.8 },
}
local GUARDS = {
	{ -1834.7, 47.8, -1323.9 }, { -1918.1, 47.3, -1312.3 }, { -1937.1, 50.6, -1365.6 }, { -1844.3, 56.1, -1420.4 },
}
local LANES = {
	north = { { -1924.5, 46.7, -1309.9 }, { -1883.0, 53.8, -1308.5 }, { -1851.4, 53.8, -1380.4 } },
	west  = { { -1959.0, 52.6, -1387.9 }, { -1937.1, 50.6, -1365.6 }, { -1874.0, 56.1, -1423.8 } },
	east  = { { -1818.7, 53.8, -1339.5 }, { -1831.3, 50.7, -1359.2 }, { -1839.2, 50.8, -1369.7 } },
}
local WAVES = {
	{ lane = "north", count = 3, level = 47 },
	{ lane = "west", count = 4, level = 48 },
	{ lane = "east", count = 4, level = 49 },
	{ lane = "north", count = 5, level = 50, leader = true },
}
local WAVE_TIMEOUT = 240

function Hamlet:setup(opts)
	self:timeLimit(TIME_LIMIT)
	self:relate("Kobold", "PlayerAlly", "hostile")
	for _, p in ipairs(CACHES) do
		self:spawn("caches", { pool = POOL_CACHE, kind = "Ally", level = 50, hp = 12000, at = p,
			tags = { "cache", "protected" }, profile = "Ai/Kinds/Structure", faction = "PlayerAlly" })
	end
	for _, p in ipairs(GUARDS) do
		self:spawn("guards", { pool = POOL_GUARD, kind = "Ally", level = 50, at = p,
			profile = "Content/Profiles/HamletGuard", override = { behaviors = { Guard = { point = p } } } })
	end
	self:objective("caches", Objective.protect("caches", 1), { fails = true })
	self:objective("leader", Objective.kill("leader"), { wins = true })
	self:objective("waves", Objective.count("wavesHeld", #WAVES), { wins = true })
end

function Hamlet:onStart()
	self:run(function()
		wait(10)
		for i, w in ipairs(WAVES) do
			local lane = LANES[w.lane]
			local specs = {}
			for k = 1, w.count do
				local s = lane[1]
				table.insert(specs, { at = { s[1] + (k - 1) * 2, s[2], s[3] } })
			end
			local name = "wave" .. i
			local wave = self:spawnGroup(specs, { pool = POOL_RAIDER, level = w.level, group = name, faction = "Kobold",
				profile = "Content/Profiles/HamletRaider",
				override = { behaviors = { Patrol = { route = { points = lane }, mode = "once", pace = "run" } } } })
			if w.leader then
				self:spawn("leader", { pool = POOL_LEADER, level = w.level + 2, hp = 18000, at = lane[1], faction = "Kobold",
					profile = "Content/Profiles/HamletRaider",
					override = { behaviors = { Patrol = { route = { points = lane }, mode = "once" } } } })
			end
			waitUntil(function() return wave:alive() == 0 end, WAVE_TIMEOUT)
			self:counter("wavesHeld", 1)
			if i < #WAVES then wait(20) end
		end
	end)
	self:on("Died", { group = "caches" }, function()
		self:broadcast(30121)
	end)
end

function Hamlet:onEnd(result)
	local campaign = Campaign.get("HamletAleport")
	if campaign then campaign:battleEnded(result, self) end
end

return Hamlet
