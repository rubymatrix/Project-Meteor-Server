--[[
Calamity Cometh (Man2u0 SEQ_010), director QuestDirectorMan2u001: Greinfarr holds the line over the
wounded at the Nanawa Mines road while minemites come one or two at a time.
Niellefresne stands passive, Greinfarr fights; either falling loses ("guarded"). Twelve minemites,
at most two up, the first FIRST_WAVE_SECONDS in and then every WAVE_INTERVAL_SECONDS; each is sent
at the player, Greinfarr or Niellefresne in turn. A minemite next to an ally chips it for
ALLY_STRIKE_DAMAGE every ALLY_STRIKE_SECONDS. The last minemite down wins. The player keeps 1 HP.
opts.quest: the quest whose lines the fight shows.
--]]

local Minemites = Encounter.define("QuestDirectorMan2u001")

local POOL_NIELLEFRESNE = 9290013
local POOL_GREINFARR = 9290014
local POOL_MINEMITE = 9202106
local FIGHT_LEVEL = 13

local TIME_LIMIT_SECONDS = 1800
local FIRST_WAVE_SECONDS = 10
local WAVE_INTERVAL_SECONDS = 22
local LIVE_CAP = 2
local ALLY_STRIKE_DAMAGE = 60
local ALLY_STRIKE_SECONDS = 8
local ALLY_STRIKE_RANGE = 4.0
local GREINFARR_REACH = 15.0
local GREINFARR_CALL_SECONDS = 40

local MOD_MINIMUM_HP_LOCK = 114
local MESSAGE_TYPE_SYSTEM = 32
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_TIME_MINUTES = 25018
local TEXT_PARTY_DEFEATED = 51147
local TEXT_LURE_THEM_TO_ME = 174
local TEXT_TO_THE_PHRONTISTERY = 38

local NIELLEFRESNE_POST = { -119.108, 215.858, -770.667, 0.604 }
local GREINFARR_POST = { -116.0, 215.623, -764.0, -2.634 }
local MINEMITE_SLOTS = {
	{ -94.5, 215.811, -768.5, -1.571 }, { -97.715, 215.495, -756.5, -2.094 },
	{ -106.5, 210.472, -747.715, -2.618 }, { -118.5, 215.312, -744.5, 3.142 },
	{ -130.5, 216.237, -747.715, 2.618 }, { -139.285, 215.623, -756.5, 2.094 },
	{ -142.5, 215.987, -768.5, 1.571 }, { -139.285, 216.527, -780.5, 1.047 },
	{ -130.5, 216.694, -789.285, 0.524 }, { -118.5, 216.666, -792.5, 0.0 },
	{ -106.5, 220.608, -789.285, -0.524 }, { -97.715, 216.687, -780.5, -1.047 },
}

local FOE_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }
-- Without a weapon her fighter class T-poses in combat, so she never fights.
local NIELLEFRESNE_PROFILE = { behaviors = { Follow = false, Assist = false, Combat = false, Avoid = false } }
local GREINFARR_PROFILE = { behaviors = { Follow = false, Assist = false } }

local function flat(a, b)
	local p, q = a:pos(), b:pos()
	return math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2)
end

function Minemites:setup(opts)
	self.quest = opts.quest
	self.player = self:participants()[1]
	self.spawned = 0
	self.nextSpawn = FIRST_WAVE_SECONDS
	self.nextStrike = {}
	self:timeLimit(TIME_LIMIT_SECONDS)
	self.niellefresne = self:spawn("allies", { pool = POOL_NIELLEFRESNE, kind = "Ally", level = FIGHT_LEVEL,
		at = NIELLEFRESNE_POST, profile = NIELLEFRESNE_PROFILE })
	self.greinfarr = self:spawn("allies", { pool = POOL_GREINFARR, kind = "Ally", level = FIGHT_LEVEL,
		at = GREINFARR_POST, profile = GREINFARR_PROFILE })
	self:objective("guarded", Objective.protect("allies", 2), { fails = true })
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Minemites:tellQuest(textId)
	if self.quest then self:tell(self.quest, textId) end
end

-- The wave alternates the player, Greinfarr and Niellefresne.
function Minemites:targetFor(slot)
	local step = slot % 3
	if step == 2 and self.greinfarr and self.greinfarr:isAlive() then
		return self.greinfarr
	elseif step == 0 and self.niellefresne and self.niellefresne:isAlive() then
		return self.niellefresne
	end
	return self.player
end

function Minemites:spawnMinemite()
	self.spawned = self.spawned + 1
	local mob = self:spawn("minemites", { pool = POOL_MINEMITE, level = FIGHT_LEVEL,
		at = MINEMITE_SLOTS[self.spawned], profile = FOE_PROFILE })
	local target = self:targetFor(self.spawned)
	if mob and target then mob:engage(target) end
	self.nextSpawn = self:elapsed() + WAVE_INTERVAL_SECONDS
end

function Minemites:sendGreinfarr(mites)
	local g = self.greinfarr
	if g == nil or not g:isAlive() or g:isEngaged() then return end
	local nearest, best = nil, GREINFARR_REACH
	for _, mob in ipairs(mites) do
		local d = flat(mob, g)
		if d <= best then nearest, best = mob, d end
	end
	if nearest then g:engage(nearest) end
end

-- True when the ally took a chip that would have felled it.
function Minemites:chip(ally, mites)
	if ally == nil or not ally:isAlive() then return false end
	local near = 0
	for _, mob in ipairs(mites) do
		if flat(mob, ally) <= ALLY_STRIKE_RANGE then near = near + 1 end
	end
	local now = self:elapsed()
	if near == 0 or now < (self.nextStrike[ally.id] or 0) then return false end
	self.nextStrike[ally.id] = now + ALLY_STRIKE_SECONDS
	local damage = ALLY_STRIKE_DAMAGE * near
	if ally:hp() <= damage then return true end
	ally:setHp(ally:hp() - damage)
	return false
end

function Minemites:liveMites()
	local out = {}
	for _, mob in ipairs(self:group("minemites"):list()) do
		if mob:isAlive() then table.insert(out, mob) end
	end
	return out
end

function Minemites:onStart()
	local p = self.player and self.player.cs
	if p then
		p:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
		-- No game message carries the "'s group" form of the objective.
		p:SendMessage(MESSAGE_TYPE_SYSTEM, "", "Protect Niellefresne's group from harm.")
		p:SendGameMessage(GetWorldMaster(), TEXT_TIME_MINUTES, 0x20, TIME_LIMIT_SECONDS / 60)
	end
	self:after(GREINFARR_CALL_SECONDS, function() self:tellQuest(TEXT_LURE_THEM_TO_ME) end)
	self:every(1, function()
		local mites = self:liveMites()
		if self.spawned < #MINEMITE_SLOTS and #mites < LIVE_CAP and self:elapsed() >= self.nextSpawn then
			self:spawnMinemite()
			mites = self:liveMites()
		end
		self:sendGreinfarr(mites)
		if self:chip(self.niellefresne, mites) or self:chip(self.greinfarr, mites) then
			if p then p:SendGameMessage(GetWorldMaster(), TEXT_PARTY_DEFEATED, 0x20) end
			self:fail("guarded")
			return false
		end
		if self.spawned >= #MINEMITE_SLOTS and #mites == 0 then
			self:tellQuest(TEXT_TO_THE_PHRONTISTERY)
			self:win("cleared")
			return false
		end
	end)
end

return Minemites
