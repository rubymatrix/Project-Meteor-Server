--[[
Man0u1 escort (director QuestDirectorMan0u102): bring Flhaminn to the camp while chinchillas wait
along the way. Lost if she falls or time runs out; won at the camp once no foe is close or fighting,
or after a few seconds there when stragglers can't reach it.
--]]

local Escort = Encounter.define("QuestDirectorMan0u102")

local POOL_FLHAMINN, POOL_CHINCHILLA = 8290008, 8204010
local ESCORT_LEVEL = 5
local TIME_LIMIT = 1800
local HOLD_RADIUS, ARRIVAL_RADIUS, NEAR_GOAL_RADIUS = 28, 20, 60
local ARRIVAL_GRACE_SECONDS = 10
local CAMP = { 34.8, 0, -480.5 }
local MOD_MINIMUM_HP_LOCK = 114

local FLHAMINN_DISPLAY_ID = 1900054
local TEXT_PROTECT_FROM_HARM, TEXT_TIME_MINUTES = 51005, 25018
local TEXT_DANGERS_AHEAD, TEXT_NOT_TOO_STRONG, TEXT_WELL_DONE, TEXT_AMAZING = 365, 366, 367, 368
local TEXT_ARE_YOU_HURT, TEXT_SO_CLOSE, TEXT_JUST_AHEAD = 369, 374, 375

local FLHAMINN_START = { -31.0, 183.0, -66.0, 2.0 }
local CHINCHILLAS = {
	{ -76.90, 181.36, -236.10 }, { -75.79, 181.29, -242.36 },
	{ -14.78, 183.96, -319.97 }, { -19.53, 184.61, -322.32 }, { -16.32, 184.29, -325.45 },
	{ -57.08, 184.50, -447.63 }, { -56.54, 184.14, -442.77 }, { -52.41, 184.50, -444.50 },
}

local function flat(a, x, z)
	local p = a:pos()
	return math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2)
end

function Escort:setup(opts)
	self.quest = opts.quest
	self.player = self:participants()[1]
	self.holdSeconds = 0
	self:timeLimit(TIME_LIMIT)
	self.flhaminn = self:spawn("escorts", { pool = POOL_FLHAMINN, kind = "Ally", level = ESCORT_LEVEL, at = FLHAMINN_START,
		profile = "Content/Profiles/EscortedChild",
		override = { bb = { leader = self.player }, behaviors = { Follow = { gap = 4 } } } })
	for _, c in ipairs(CHINCHILLAS) do
		self:spawn("chinchillas", { pool = POOL_CHINCHILLA, level = self:int(5, 7), at = c })
	end
	self:objective("escorts", Objective.protect("escorts", 1), { fails = true })
	self:objective("camp", Objective.custom(function() return self:arrived() end), { wins = true })
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Escort:say(textId)
	if self.quest then self:tell(self.quest, textId) end
end

function Escort:foesNear()
	local n, engaged = 0, false
	for _, mob in ipairs(self:group("chinchillas"):list()) do
		if mob:isAlive() then
			if mob:distance(self.player) <= HOLD_RADIUS or (self.flhaminn and mob:distance(self.flhaminn) <= HOLD_RADIUS) then
				n = n + 1
			end
			engaged = engaged or mob:isEngaged()
		end
	end
	return n, engaged
end

function Escort:arrived()
	if self.player == nil or flat(self.player, CAMP[1], CAMP[3]) > ARRIVAL_RADIUS then return false end
	local near, engaged = self:foesNear()
	return (near == 0 and not engaged) or self.holdSeconds >= ARRIVAL_GRACE_SECONDS
end

function Escort:onStart()
	local p = self.player
	if p then
		p.cs:SendGameMessage(GetWorldMaster(), TEXT_PROTECT_FROM_HARM, 0x20, FLHAMINN_DISPLAY_ID)
		p.cs:SendGameMessage(GetWorldMaster(), TEXT_TIME_MINUTES, 0x20, TIME_LIMIT / 60)
	end
	self:say(TEXT_DANGERS_AHEAD)

	local lastNear, saidSoClose, tick = 0, false, 0
	self:every(1, function()
		if not p then return false end
		tick = tick + 1
		local near = self:foesNear()
		if near == 0 and lastNear > 0 then
			self:say(tick % 2 == 0 and TEXT_WELL_DONE or TEXT_ARE_YOU_HURT)
			self:say(TEXT_AMAZING)
		end
		lastNear = near
		local toCamp = flat(p, CAMP[1], CAMP[3])
		if not saidSoClose and toCamp <= NEAR_GOAL_RADIUS then
			saidSoClose = true
			self:say(TEXT_SO_CLOSE)
		end
		self.holdSeconds = toCamp <= ARRIVAL_RADIUS and self.holdSeconds + 1 or 0
	end)

	self:on("Engaged", { group = "chinchillas" }, function() self:say(TEXT_NOT_TOO_STRONG) end)
end

function Escort:onEnd(result)
	if result == "win" then self:say(TEXT_JUST_AHEAD) end
end

return Escort
