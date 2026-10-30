--[[
Together We Stand (Man206 SEQ_020/025): the stealth run through Moonspore Grove. Sentries see
by this script, not by their senses. The player keeps 1 HP; only the quest wins it, with the
delivery. Rules, groups and counters: Data/Docs/Scripts/Content/Quest/QuestDirectorMan20601.md.
--]]

local Grove = Encounter.define("QuestDirectorMan20601")

local POOL_TRIARIUS = 9280002
local POOL_SPECULATOR = 9280008
local POOL_RETIARIUS = 8280004
local POOL_HASTATUS = 8280005
local SENTRY_LEVEL = 22

local TIME_LIMIT_SECONDS = 1800
local SIGHT_RANGE = 10.0
local CONCEALED_SIGHT = 3.0
local HALT_RANGE = 4.0
local NOTICE_RANGE = 25.0
local LEASH_RANGE = 40.0
local CONCEAL_SECONDS = 30
local COMPANION_FOLLOW = 5.0
local COMPANION_FAIL_RANGE = 60.0
local COMPANION_FAIL_SECONDS = 10

local MOD_MINIMUM_HP_LOCK = 114
local ITEM_PODLING = 11000091
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_OBJECTIVE = 51004
local TEXT_TIME_MINUTES = 25018
local TEXT_CONCEALED = 569
local TEXT_CONCEAL_WORN = 570

-- Northbound posts first, then the return leg.
local SENTRIES = {
	{ POOL_RETIARIUS, 2045.685, 32.202, -1066.061, -2.886 },
	{ POOL_RETIARIUS, 2197.018, 31.981, -1276.283, -1.602 },
	{ POOL_TRIARIUS, 2180.387, 40.930, -1417.888, -1.169 },
	{ POOL_TRIARIUS, 2154.995, 49.733, -1589.024, 1.203 },
	{ POOL_HASTATUS, 2159.232, 49.156, -1477.923, 2.284 },
	{ POOL_SPECULATOR, 2032.731, 39.953, -1099.115, -0.486 },
	{ POOL_RETIARIUS, 2135.319, 31.936, -1084.873, -1.318 },
}

local SENTRY_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }

local function flat(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

function Grove:setup(opts)
	self.quest = opts.quest
	self.player = self:participants()[1]
	self.sentries = {}
	self:timeLimit(TIME_LIMIT_SECONDS)
	for i, s in ipairs(SENTRIES) do
		local mob = self:spawn("sentries", { pool = s[1], level = SENTRY_LEVEL, at = { s[2], s[3], s[4], s[5] },
			group = { "sentries", "sentry" .. i }, profile = SENTRY_PROFILE })
		if mob then table.insert(self.sentries, { mob = mob, home = s, index = i }) end
	end
	self.companion = self.cs.Area:FindActorInZoneByUniqueID("man206_companion")
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Grove:tellQuest(textId)
	if self.quest then self:tell(self.quest, textId) end
end

function Grove:phase_cover()
	self.concealedUntil = self:elapsed() + CONCEAL_SECONDS
	self.coverTaken = true
	self:tellQuest(TEXT_CONCEALED)
end

function Grove:watch(player)
	local takeCover = self.coverTaken
	self.coverTaken = false
	if not takeCover and self.concealedUntil ~= nil and self:elapsed() >= self.concealedUntil then
		self.concealedUntil = nil
		self:tellQuest(TEXT_CONCEAL_WORN)
	end
	local range = self.concealedUntil ~= nil and CONCEALED_SIGHT or SIGHT_RANGE
	for _, s in ipairs(self.sentries) do
		local mob = s.mob
		if mob:isAlive() then
			local cs = mob.cs
			local d = flat(cs.positionX, cs.positionZ, player.positionX, player.positionZ)
			if s.engaged then
				if takeCover or flat(player.positionX, player.positionZ, s.home[2], s.home[4]) > LEASH_RANGE then
					mob:clearHate()
					s.engaged, s.halted = false, false
				elseif not s.halted and d <= HALT_RANGE then
					s.halted = true
					self:counter("halted" .. s.index, 1)
				end
			elseif mob:isEngaged() then
				s.engaged = true
			else
				if d <= NOTICE_RANGE and self:counter("sentryNear") == 0 then self:counter("sentryNear", 1) end
				if d <= range and cs:IsFacing(player.positionX, player.positionZ, 180) then
					s.engaged = true
					self:counter("sighted" .. s.index, 1)
					mob:engage(self.player)
				end
			end
		end
	end
end

-- True once the companion has been left behind for COMPANION_FAIL_SECONDS.
function Grove:companionLost(player)
	local c = self.companion
	if c == nil then return false end
	local d = flat(c.positionX, c.positionZ, player.positionX, player.positionZ)
	if d > COMPANION_FOLLOW then c:FollowTarget(player, 1.2, 25, COMPANION_FOLLOW - 1) end
	if d <= COMPANION_FAIL_RANGE then
		self.awaySeconds = 0
		return false
	end
	self.awaySeconds = self.awaySeconds + 1
	return self.awaySeconds >= COMPANION_FAIL_SECONDS
end

function Grove:onStart()
	self.awaySeconds = 0
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:tell(nil, TEXT_OBJECTIVE, ITEM_PODLING, 0)
	self:tell(nil, TEXT_TIME_MINUTES, TIME_LIMIT_SECONDS / 60)
	self:every(1, function()
		local player = self.player and self.player.cs
		if player == nil then return end
		self:watch(player)
		if self:companionLost(player) then
			self:fail("companion")
			return false
		end
	end)
end

return Grove
