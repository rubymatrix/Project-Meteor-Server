--[[
Futures Perfect (Man406 SEQ_015), director QuestDirectorMan40601: the field duty in Mor Dhona.
WALK_START_SECONDS in, the centurion walks the track to the juggernaut with his sagittarius and
hoplomachus behind. They never fight back while they walk, and hold at 1 HP. At the track's end the
counter "ambush" goes up and the fight waits for the quest's scene, which moves it to phase "fight".
The fight: the player at full HP and MP, all three on the player (only the centurion still held at 1 HP),
the juggernaut in place to fire its Magitek Cannon. A warning marker drops on the player
CANNON_FIRST_IMPACT - CANNON_WINDUP seconds in and every CANNON_CADENCE after; CANNON_WINDUP later it
fires if the player is still within CANNON_RADIUS of it. Both escorts down: at the next impact (at most
FLEE_CAP_SECONDS later) the centurion flees; he reaches the end with the player within LEASH_DISTANCE:
won. The player LEASH_DISTANCE from the action for LEASH_SECONDS fails ("left").
--]]

local Field = Encounter.define("QuestDirectorMan40601")

local IMPERIAL_LEVEL = 46
local JUGGERNAUT_LEVEL = 50
local POOL_CENTURION = 8207001
local POOL_HOPLOMACHUS = 8280003
local POOL_SAGITTARIUS = 8280006
local POOL_JUGGERNAUT = 8202401
local ACTION_MAGITEK_CANNON = 23224
local WARNING_MARKER = 1080056

local MOD_MINIMUM_HP_LOCK = 114
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_TRACK_TARGET = 51019
local TEXT_DEFEAT_ENEMY_GROUP = 51003
local TEXT_USE_ENEMY_COMMAND = 51049
local TEXT_ENEMY_FLEEING = 50048
local TEXT_MINUTES_REMAINING = 25018
local TEXT_SECONDS_REMAINING = 25019
local TEXT_LEAVING_INSTANCE = 34109
local TEXT_LEFT_INSTANCE = 34110
local DISPLAY_CENTURION = 3207001
local DISPLAY_JUGGERNAUT = 3202401

local TIME_LIMIT_SECONDS = 1800
local WALK_START_SECONDS = 3
local WAYPOINT_REACHED = 2.5
local SAGITTARIUS_LAG = 2.5
local HOPLOMACHUS_LAG = 5.0
local LEASH_DISTANCE = 60.0
local LEASH_SECONDS = 10
local ENEMY_GROUP_COUNT = 3
local CANNON_HINT_SECONDS = 5
local CANNON_WINDUP = 8
local CANNON_FIRST_IMPACT = 35
local CANNON_CADENCE = 50
local CANNON_RADIUS = 6.0
local FLEE_CAP_SECONDS = 45

local TRACK = {
	{ -191.004, 20.131, -697.503 }, { -167.504, 18.931, -703.503 }, { -119.004, 20.131, -700.503 },
	{ -0.004, 20.131, -704.003 }, { 7.057, 20.722, -704.071 }, { 19.996, 22.931, -698.503 },
	{ 21.496, 23.331, -697.503 }, { 23.496, 26.131, -688.503 }, { 26.996, 28.131, -686.003 },
	{ 74.996, 33.731, -685.003 }, { 76.996, 34.131, -684.003 }, { 101.496, 38.931, -669.003 },
	{ 122.996, 44.131, -644.503 }, { 173.43, 43.183, -641.26 },
}
local FLEE_PATH = {
	{ 182.257, 44.155, -643.488 }, { 198.496, 45.331, -650.003 }, { 200.496, 46.131, -651.503 },
	{ 206.996, 46.131, -659.503 }, { 223.996, 46.531, -687.503 }, { 231.496, 45.731, -691.503 },
	{ 240.496, 44.131, -691.503 }, { 248.496, 44.531, -690.503 }, { 260.996, 44.931, -687.503 },
	{ 280.67, 45.903, -679.972 },
}
-- The last man starts on the imperial mark, the others ahead of him on the track.
local CENTURION_START = { -208.6, 19.4, -691.41, 1.904 }
local SAGITTARIUS_START = { -210.96, 19.3, -690.59, 1.904 }
local HOPLOMACHUS_START = { -213.322, 19.143, -689.771, 1.904 }
local JUGGERNAUT_POST = { 188.595, 43.948, -640.177, -1.428 }

-- Walked by the script: no aggro and no fighting back, still targetable.
local WALKER_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false, Leash = false, Combat = false } }
-- Never killed and never moving: the fight only needs its cannon.
local JUGGERNAUT_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false, Leash = false, Combat = false } }

local function flat(a, b)
	return math.sqrt((a.positionX - b.positionX) ^ 2 + (a.positionZ - b.positionZ) ^ 2)
end

local function flatTo(a, p)
	return math.sqrt((a.positionX - p[1]) ^ 2 + (a.positionZ - p[3]) ^ 2)
end

local function alive(a)
	return a ~= nil and a:isAlive()
end

function Field:setup()
	self.player = self:participants()[1]
	self:timeLimit(TIME_LIMIT_SECONDS)
	local function spawnWalker(group, pool, at)
		local mob = self:spawn(group, { pool = pool, level = IMPERIAL_LEVEL, at = at,
			group = { group, "imperials" }, profile = WALKER_PROFILE })
		if mob then mob.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
		return mob
	end
	self.centurion = spawnWalker("centurion", POOL_CENTURION, CENTURION_START)
	self.sagittarius = spawnWalker("escorts", POOL_SAGITTARIUS, SAGITTARIUS_START)
	self.hoplomachus = spawnWalker("escorts", POOL_HOPLOMACHUS, HOPLOMACHUS_START)
end

-- An objective is a banner and a log line.
function Field:announce(textId, ...)
	for _, p in ipairs(self:participants()) do
		p.cs:SendDataPacket("attention", GetWorldMaster(), "", textId, ...)
	end
	self:tell(nil, textId, ...)
end

-- The clock lines at 20, 10 and 5 minutes left, then 30 seconds.
function Field:remind()
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

function Field:startTrack()
	local c = self.centurion
	c:push("Walk", { id = "track", points = TRACK, pace = "walk" })
	if alive(self.sagittarius) then
		self.sagittarius:add("Follow", { leader = c, gap = SAGITTARIUS_LAG, slot = "rear" }, "trail")
	end
	if alive(self.hoplomachus) then
		self.hoplomachus:add("Follow", { leader = c, gap = HOPLOMACHUS_LAG, slot = "rear" }, "trail")
	end
end

function Field:clearMarker()
	if self.marker ~= nil then
		self.cs.Area:DespawnActor(self.marker)
		self.marker = nil
	end
end

function Field:phase_fight()
	local player = self.player
	if player == nil then return end
	self.stage = "fight"
	self.fightAt = self:elapsed()
	self.nextWindup = self.fightAt + CANNON_FIRST_IMPACT - CANNON_WINDUP
	player.cs:SetHP(player.cs:GetMaxHP())
	player.cs:SetMP(player.cs:GetMaxMP())
	self:group("imperials"):each(function(mob)
		if not mob:isAlive() then return end
		mob:remove("track")
		mob:remove("trail")
		mob:add("Combat", {})
		if mob.cs ~= self.centurion.cs then mob.cs:SetMod(MOD_MINIMUM_HP_LOCK, 0) end
		mob:engage(player)
	end)
	local jug = self:spawn("juggernaut", { pool = POOL_JUGGERNAUT, level = JUGGERNAUT_LEVEL, at = JUGGERNAUT_POST,
		profile = JUGGERNAUT_PROFILE })
	if jug then
		jug.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
		jug:push("Hold", { id = "post" })
	end
	self.juggernaut = jug
	self:announce(TEXT_DEFEAT_ENEMY_GROUP, DISPLAY_CENTURION, ENEMY_GROUP_COUNT)
	self:after(CANNON_HINT_SECONDS, function()
		self:announce(TEXT_USE_ENEMY_COMMAND, DISPLAY_JUGGERNAUT, 1, ACTION_MAGITEK_CANNON)
	end)
end

-- The blast point freezes on the player as the warning appears.
function Field:tickCannon(player)
	local now = self:elapsed()
	if self.impactAt ~= nil and now >= self.impactAt then
		self.impactAt = nil
		self:clearMarker()
		local p = self.markerPos
		if alive(self.juggernaut) and math.sqrt((player.positionX - p[1]) ^ 2 + (player.positionZ - p[3]) ^ 2) <= CANNON_RADIUS then
			self.juggernaut:use(ACTION_MAGITEK_CANNON, self.player)
		end
	end
	if self.nextWindup ~= nil and now >= self.nextWindup and alive(self.juggernaut) then
		self.nextWindup = self.nextWindup + CANNON_CADENCE
		self.markerPos = { player.positionX, player.positionY, player.positionZ }
		local p = self.markerPos
		self.marker = self.cs.Area:SpawnActor(WARNING_MARKER, "man406_cannon_warning", p[1], p[2], p[3], 0.0)
		self.impactAt = now + CANNON_WINDUP
	end
end

function Field:startFlee()
	local c = self.centurion
	self.stage = "flee"
	c:remove("Combat")
	c:disengage()
	c:push("Walk", { id = "flee", points = FLEE_PATH, pace = "walk" })
	self:announce(TEXT_ENEMY_FLEEING, DISPLAY_CENTURION, 1)
end

function Field:tickFight()
	local now = self:elapsed()
	if self.fleeStart == nil and not alive(self.sagittarius) and not alive(self.hoplomachus) then
		local nextImpact = self.fightAt + CANNON_FIRST_IMPACT
		while nextImpact <= now do
			nextImpact = nextImpact + CANNON_CADENCE
		end
		self.fleeStart = math.min(nextImpact, now + FLEE_CAP_SECONDS)
	end
	if self.fleeStart ~= nil and now >= self.fleeStart then self:startFlee() end
end

-- True once the player has strayed from the action for LEASH_SECONDS: the centurion while he walks or
-- flees, the track's end in the fight.
function Field:leashBroken(player)
	local away
	if self.stage == "fight" then
		away = flatTo(player, TRACK[#TRACK])
	else
		away = flat(player, self.centurion.cs)
	end
	if away <= LEASH_DISTANCE then
		self.awaySeconds = 0
		return false
	end
	self.awaySeconds = self.awaySeconds + 1
	if self.awaySeconds == 1 then self:tell(nil, TEXT_LEAVING_INSTANCE) end
	if self.awaySeconds < LEASH_SECONDS then return false end
	self:tell(nil, TEXT_LEFT_INSTANCE)
	return true
end

function Field:tick()
	local player = self.player and self.player.cs
	if player == nil or self.centurion == nil then return end
	self:remind()
	local c = self.centurion.cs
	if self.stage == "track" then
		if self:elapsed() >= WALK_START_SECONDS and not self.walking then
			self.walking = true
			self:startTrack()
		end
		if self.walking and flatTo(c, TRACK[#TRACK]) <= WAYPOINT_REACHED then
			self.stage = "ambush"
			self:counter("ambush", 1)
		end
	elseif self.stage == "fight" or self.stage == "flee" then
		self:tickCannon(player)
		if self.stage == "fight" then
			self:tickFight()
		elseif flatTo(c, FLEE_PATH[#FLEE_PATH]) <= WAYPOINT_REACHED and flatTo(player, FLEE_PATH[#FLEE_PATH]) <= LEASH_DISTANCE then
			self.stage = "won"
			if alive(self.juggernaut) then self.juggernaut:disengage() end
			player:Disengage()
			self:clearMarker()
			self:win("fled")
			return false
		end
	end
	if self.stage ~= "ambush" and self:leashBroken(player) then
		self:fail("left")
		return false
	end
end

function Field:onStart()
	self.stage, self.said, self.awaySeconds = "track", {}, 0
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:announce(TEXT_TRACK_TARGET, DISPLAY_CENTURION, 1)
	self:announce(TEXT_MINUTES_REMAINING, TIME_LIMIT_SECONDS / 60)
	self:every(1, function() return self:tick() end)
end

function Field:onEnd()
	self:clearMarker()
end

return Field
