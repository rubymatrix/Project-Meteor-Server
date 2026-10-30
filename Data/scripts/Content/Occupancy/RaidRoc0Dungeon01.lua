--[[
Dzemael Darkhold (director /Director/Occupancy/RaidRoc0Dungeon01): two linked bat packs, a bomb and a
beastmaster with his hound; a gate that opens when the room is clear; a patrolling pair; the warden,
a child encounter that starts when a player reaches his room. Mobs and models are stand-ins.
--]]

local Darkhold = ContentArea.define("RaidRoc0Dungeon01")

Darkhold.area = {
	zone = 231,
	classPath = "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent",
	name = "raidRoc0Dungeon01",
	script = "SimpleContentOccupancy",
	director = "Occupancy/RaidRoc0Dungeon01",
}
Darkhold.entry = { -93.9, 165.2, -78.5, 0 }

local POOL_BAT, POOL_BOMB, POOL_BEASTMASTER, POOL_HOUND = 9300010, 9300011, 9300012, 9300013
local LEVEL = 25

local ROOM1 = {
	{ pool = POOL_BAT, at = { -68.5, 171.0, -75.6 }, pack = 1 },
	{ pool = POOL_BAT, at = { -67.3, 170.9, -76.5 }, pack = 1 },
	{ pool = POOL_BOMB, at = { -24.0, 172.2, -11.6 } },
	{ pool = POOL_BAT, at = { -20.7, 172.4, -13.1 }, pack = 2 },
	{ pool = POOL_BAT, at = { -29.0, 171.6, -18.3 }, pack = 2 },
}

local PATROL = {
	{ 35.7, 177.3, 45.7, name = "west" }, { 48.7, 178.1, 46.8 }, { 39.0, 176.0, 39.5, name = "east", wait = 3 },
}

function Darkhold:setup()
	self:timeLimit(60 * 60)
	for _, m in ipairs(ROOM1) do
		self:spawn("room1", { pool = m.pool, level = LEVEL, at = m.at,
			override = m.pack and { bb = { pack = m.pack }, behaviors = { Link = { by = "pack", radius = 12 } } } or nil })
	end

	local master = self:spawn("room1", { pool = POOL_BEASTMASTER, level = LEVEL, at = { -29.0, 171.6, -14.0 },
		profile = { faction = "Monster", behaviors = { Detect = {}, Roam = false } } })
	if master then
		self:spawn("room1", { pool = POOL_HOUND, level = LEVEL, at = { -27.0, 171.6, -14.0 }, owner = master,
			override = { behaviors = { Roam = false, Follow = { leader = "owner", gap = 2 }, Assist = { leader = "owner" } } } })
	end

	self:spawn("room2", { pool = POOL_BAT, level = LEVEL, at = PATROL[1],
		override = { behaviors = { Roam = false, Patrol = { route = { points = PATROL }, mode = "pingpong" } } } })

	-- The gate between the first room and the rest.
	self:region("gate", { circle = { centre = { 5, 174, 20 }, radius = 6 }, blocks = true })
	self:region("bossRoom", { circle = { centre = { 16.2, 173.9, 98 }, radius = 12 } })
	self:objective("warden", Objective.custom(function() return self.wardenDown end), { wins = true })
end

function Darkhold:onStart()
	self:on("Died", { allDead = true, group = "room1" }, function()
		self:door("gate").open()
		self:broadcast(30121)
	end)
	self:onRegion("bossRoom", function()
		self:child("RaidRoc0Dungeon01Warden")
	end)
end

function Darkhold:onEncounterEnded(ev)
	if ev.name == "RaidRoc0Dungeon01Warden" and ev.data == "win" then self.wardenDown = true end
end

return Darkhold
