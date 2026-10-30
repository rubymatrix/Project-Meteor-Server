--[[
Of Men They Sing (Man402 SEQ_005): the search in the East Shroud. The Path companion leads the
player to the scout, then fights two bloodhounds beside them. Rules and counters:
Data/Docs/Scripts/Content/Quest/QuestDirectorMan40201.md.
--]]

local Search = Encounter.define("QuestDirectorMan40201")

local LEVEL = 42
local POOL_BLOODHOUND = 8201417
local POOL_COMPANION = 8070001
local COMPANION_CLASS_BASE = 1070000
local HOUNDS = {
	{ 1849.898, 18.714, -1714.503, -0.339 },
	{ 1854.605, 17.494, -1708.501, -0.339 },
}
local SCOUT_POST = { 1852.386, 16.784, -1707.334 }

local TRAIL = {
	{ 1979.0, 32.6, -1528.5 }, { 1987.0, 31.4, -1540.5 }, { 2004.5, 33.8, -1544.5 }, { 2026.0, 34.6, -1543.0 },
	{ 2032.5, 33.8, -1546.0 }, { 2038.0, 35.4, -1564.0 }, { 2042.5, 34.2, -1580.5 }, { 2040.0, 33.0, -1599.0 },
	{ 2033.5, 32.6, -1602.0 }, { 2012.0, 33.0, -1605.0 }, { 1995.0, 33.4, -1612.0 }, { 1975.5, 33.0, -1640.5 },
	{ 1961.0, 32.2, -1658.5 }, { 1952.0, 32.2, -1664.0 }, { 1932.5, 31.4, -1672.0 }, { 1923.5, 32.2, -1673.0 },
	{ 1909.0, 32.6, -1672.5 }, { 1905.0, 31.0, -1668.0 }, { 1907.0, 28.6, -1658.0 }, { 1914.0, 26.6, -1655.5 },
	{ 1916.0, 25.8, -1656.5 }, { 1915.5, 21.4, -1676.5 }, { 1925.0, 20.2, -1666.0 }, { 1927.0, 19.8, -1658.5 },
	{ 1924.0, 20.2, -1684.0 }, { 1924.5, 20.2, -1700.5 }, { 1926.5, 20.2, -1712.5 }, { 1921.0, 20.2, -1728.0 },
	{ 1916.5, 20.6, -1733.5 }, { 1910.0, 20.2, -1733.0 }, { 1876.0, 21.0, -1727.5 }, { 1864.5, 20.6, -1723.0 },
	{ 1857.0, 18.6, -1712.0 },
}

local MOD_MINIMUM_HP_LOCK = 114
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_MINUTES_REMAINING = 25018
local TEXT_SECONDS_REMAINING = 25019
local TEXT_LEAVING_INSTANCE = 34109
local TEXT_LEFT_INSTANCE = 34110

local TIME_LIMIT_SECONDS = 1800
local WALK_START_SECONDS = 3
local WAYPOINT_REACHED = 2.5
local HOLD_DISTANCE = 20.0
local LEASH_DISTANCE = 60.0
local LEASH_SECONDS = 10
local ARRIVAL_RANGE = 20.0
local ENGAGE_DELAY = 10
local ENGAGE_RANGE = 12.0
local WIN_SETTLE_SECONDS = 6

local FOE_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }

local function flat(a, b)
	return math.sqrt((a.positionX - b.positionX) ^ 2 + (a.positionZ - b.positionZ) ^ 2)
end

local function flatTo(a, p)
	return math.sqrt((a.positionX - p[1]) ^ 2 + (a.positionZ - p[3]) ^ 2)
end

function Search:setup()
	self.player = self:participants()[1]
	self:timeLimit(TIME_LIMIT_SECONDS)
	for _, h in ipairs(HOUNDS) do
		self:spawn("hounds", { pool = POOL_BLOODHOUND, level = LEVEL, at = h, profile = FOE_PROFILE })
	end
	self.lead = self.cs.Area:FindActorInZoneByUniqueID("man402_companion")
end

-- The clock lines at 20, 10 and 5 minutes left, then 30 seconds.
function Search:remind()
	local left = self:remaining()
	for _, m in ipairs({ 20, 10, 5 }) do
		if left <= m * 60 and not self.said[m] then
			self.said[m] = true
			self:tell(nil, TEXT_MINUTES_REMAINING, m)
		end
	end
	if left <= 30 and not self.said[0] then
		self.said[0] = true
		self:tell(nil, TEXT_SECONDS_REMAINING, 30)
	end
end

-- One waypoint at a time, holding for a player who trails.
function Search:walkLead(player)
	local lead = self.lead
	if lead == nil or self.trailDone or self:elapsed() < WALK_START_SECONDS then return end
	if flatTo(lead, TRAIL[self.waypoint]) <= WAYPOINT_REACHED then
		self.waypoint = self.waypoint + 1
		self.trailDone = self.waypoint > #TRAIL
	end
	if not self.trailDone and flat(lead, player) <= HOLD_DISTANCE then
		local p = TRAIL[self.waypoint]
		lead:PathTo(p[1], p[2], p[3])
	end
end

-- True once the player has strayed from the leading companion for LEASH_SECONDS.
function Search:leashBroken(player)
	if self.lead == nil or self.trailDone or flat(self.lead, player) <= LEASH_DISTANCE then
		self.awaySeconds = 0
		return false
	end
	self.awaySeconds = self.awaySeconds + 1
	if self.awaySeconds == 1 then self:tell(nil, TEXT_LEAVING_INSTANCE) end
	if self.awaySeconds < LEASH_SECONDS then return false end
	self:tell(nil, TEXT_LEFT_INSTANCE)
	return true
end

-- The leading event actor steps aside for the fighting ally where she stands.
function Search:joinFight(player)
	local lead = self.lead
	if lead == nil then return end
	local ally = self:spawn("companion", { pool = POOL_COMPANION, kind = "Ally", level = LEVEL,
		at = { lead.positionX, lead.positionY, lead.positionZ, lead.rotation },
		classId = COMPANION_CLASS_BASE + player:GetSNpcSkin(), name = player:GetSNpcNickname(),
		override = { bb = { leader = self.player } } })
	if ally == nil then return end
	ally.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
	self.cs.Area:DespawnActor(lead)
	self.lead = nil
end

function Search:houndEngaged()
	for _, mob in ipairs(self:group("hounds"):list()) do
		if mob:isAlive() and mob:isEngaged() then return true end
	end
	return false
end

function Search:tick()
	local player = self.player and self.player.cs
	if player == nil then return end
	self:remind()
	self:walkLead(player)
	if self:leashBroken(player) then
		self:fail("left")
		return false
	end

	local houndEngaged = self:houndEngaged()
	local nearScout = flatTo(player, SCOUT_POST)
	if self.arrivedAt == nil and (self.trailDone or houndEngaged or nearScout <= ARRIVAL_RANGE) then
		self.arrivedAt = self:elapsed()
		self.trailDone = true
		self:joinFight(player)
		self:counter("arrived", 1)
	end
	if self.arrivedAt ~= nil and not self.engaged
		and (self:elapsed() - self.arrivedAt >= ENGAGE_DELAY or houndEngaged or nearScout <= ENGAGE_RANGE) then
		self.engaged = true
		self:group("hounds"):each(function(mob)
			if mob:isAlive() then mob:engage(self.player) end
		end)
	end
	if not self.engaged then return end

	local kills = #HOUNDS - self:group("hounds"):alive()
	if kills > self:counter("kills") then self:counter("kills", kills - self:counter("kills")) end
	if kills >= #HOUNDS then
		self.defeatedAt = self.defeatedAt or self:elapsed()
		if self:elapsed() - self.defeatedAt >= WIN_SETTLE_SECONDS then
			self:win("cleared")
			return false
		end
	end
end

function Search:onStart()
	self.said, self.waypoint, self.awaySeconds = {}, 1, 0
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:tell(nil, TEXT_MINUTES_REMAINING, TIME_LIMIT_SECONDS / 60)
	self:every(1, function() return self:tick() end)
end

return Search
