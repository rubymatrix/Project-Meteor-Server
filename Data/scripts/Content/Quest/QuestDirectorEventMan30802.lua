--[[
Lord Errant (Man308 SEQ_015), director QuestDirectorEventMan30802: the Bowl of Embers.
"Stop the tempered captives": three captives stand until struck and hold at 1 HP; each one at its floor
loses the will to fight and stands inert. No clock in this phase.
Then the Amalj'aa war party (two lancers, an archer, an augur): the objective, and WAVE_ENGAGE_SECONDS
later the 30-minute clock and their charge. The last one down and WIN_SETTLE_SECONDS more win.
The player's Path companion fights beside them and holds at 1 HP.
Counters for the quest: "captive<n>" once captive n stands down, "subdued" how many have, "stopped" once
the war party is out.
--]]

local Bowl = Encounter.define("QuestDirectorEventMan30802")

local LEVEL = 38
local POOL_AMALJAA_LANCER = 8206508
local POOL_AMALJAA_ARCHER = 8206512
local POOL_AMALJAA_AUGUR = 8206518
local POOL_COMPANION = 8070001
local COMPANION_CLASS_BASE = 1070000

local CAPTIVES = {
	{ pool = 8289001, at = { 2526.0, 249.5, 2222.0, 2.356 } },
	{ pool = 8289002, at = { 2534.0, 249.5, 2225.0, 3.142 } },
	{ pool = 8289003, at = { 2542.0, 249.5, 2222.0, -2.356 } },
}

local WAR_PARTY = {
	{ POOL_AMALJAA_LANCER, 2529.0, 249.5, 2231.0, 2.856 },
	{ POOL_AMALJAA_LANCER, 2539.0, 249.5, 2231.0, -2.856 },
	{ POOL_AMALJAA_ARCHER, 2534.0, 249.5, 2236.0, 3.142 },
	{ POOL_AMALJAA_AUGUR, 2534.0, 249.5, 2238.5, 3.142 },
}
local COMPANION_AT = { 2531.5, 249.4, 2212.0, -1.758 }

local MOD_MINIMUM_HP_LOCK = 114
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_STOP_TEMPERED_CAPTIVES = 51021
local TEXT_LOST_WILL_TO_FIGHT = 51002
local TEXT_DISENGAGE_20_SECONDS = 32606
local TEXT_DEFEAT_ENEMY_GROUP = 51003
local TEXT_MINUTES_REMAINING = 25018
local TEXT_SECONDS_REMAINING = 25019
local DISPLAY_TEMPERED_CAPTIVE = 4000596
local DISPLAY_AMALJAA_LANCER = 3106508

local TIME_LIMIT_SECONDS = 1800
local WAVE_ENGAGE_SECONDS = 5
local WIN_SETTLE_SECONDS = 25

local FOE_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }

function Bowl:setup()
	local player = self:participants()[1]
	self.player = player
	self.captives = {}
	for i, c in ipairs(CAPTIVES) do
		local mob = self:spawn("captives", { pool = c.pool, level = LEVEL, at = c.at, profile = FOE_PROFILE })
		if mob then
			mob.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
			self.captives[i] = mob
		end
	end
	if player then
		local companion = self:spawn("companion", { pool = POOL_COMPANION, kind = "Ally", level = LEVEL, at = COMPANION_AT,
			classId = COMPANION_CLASS_BASE + player.cs:GetSNpcSkin(), name = player.cs:GetSNpcNickname(),
			override = { bb = { leader = player } } })
		if companion then companion.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
	end
end

-- No aggro, no swings, no movement, no target.
function Bowl:makeInert(mob)
	mob:remove("Combat")
	mob:disengage()
	mob:push("Hold", { id = "inert", channels = { "Move", "Face", "Act", "Target" } })
	self.cs:SetTargetable(mob.cs, false)
end

function Bowl:withdraw(i, mob)
	self.withdrawn[i] = true
	self:tell(nil, TEXT_LOST_WILL_TO_FIGHT, DISPLAY_TEMPERED_CAPTIVE, 1)
	self:tell(nil, TEXT_DISENGAGE_20_SECONDS)
	self:makeInert(mob)
	local p = self.player and self.player.cs
	if p and p.target ~= nil and p.target.Id == mob.cs.Id then p:Disengage() end
	self:counter("subdued", 1)
	self:counter("captive" .. i, 1)
end

function Bowl:callWarParty()
	self:counter("stopped", 1)
	for _, w in ipairs(WAR_PARTY) do
		self:spawn("warParty", { pool = w[1], level = LEVEL, at = { w[2], w[3], w[4], w[5] }, profile = FOE_PROFILE })
	end
	self:tell(nil, TEXT_DEFEAT_ENEMY_GROUP, DISPLAY_AMALJAA_LANCER, 2)
	self:after(WAVE_ENGAGE_SECONDS, function() self:charge() end)
end

-- The clock lines at 20, 10 and 5 minutes left, then 30 seconds.
function Bowl:remind()
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

function Bowl:charge()
	self:timeLimit(self:elapsed() + TIME_LIMIT_SECONDS)
	self:tell(nil, TEXT_MINUTES_REMAINING, TIME_LIMIT_SECONDS / 60)
	self:group("warParty"):each(function(mob)
		if mob:isAlive() and self.player then mob:engage(self.player) end
	end)
	local clearedAt
	self:every(1, function()
		self:remind()
		if self:group("warParty"):alive() > 0 then return end
		clearedAt = clearedAt or self:elapsed()
		if self:elapsed() - clearedAt >= WIN_SETTLE_SECONDS then
			self:win("cleared")
			return false
		end
	end)
end

function Bowl:onStart()
	self.withdrawn, self.said = {}, {}
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:tell(nil, TEXT_STOP_TEMPERED_CAPTIVES)
	self:every(1, function()
		local settled = 0
		for i = 1, #CAPTIVES do
			local mob = self.captives[i]
			if mob == nil or self.withdrawn[i] then
				settled = settled + 1
			elseif mob:hp() <= 1 then
				self:withdraw(i, mob)
				settled = settled + 1
			end
		end
		if settled == #CAPTIVES then
			self:callWarParty()
			return false
		end
	end)
end

return Bowl
