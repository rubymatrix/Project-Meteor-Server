--[[
Beckon of the Elementals (Man2g0 SEQ_004), director QuestDirectorMan2g001: the spirit of the wood in
the West Shroud.
Grinnaux, Handeloup and T'kebbe fight the spirit while the player supports. Its aspect turns earth,
wind, water: FIRST_ASPECT_SECONDS after the fight is joined, then every ASPECT_SECONDS. Each turn: its
line and O-App-Pesi's call, repeated every CALL_REPEAT_SECONDS for up to CALL_TIMEOUT_SECONDS. Every
STRIKE_SECONDS while the player's ward is not the aspect: ALLY_STRIKE_DAMAGE to each archer and
PLAYER_STRIKE_DAMAGE to the player, who keeps 1 HP. A fallen archer is replaced once,
REPLACEMENT_SECONDS later. Won when the spirit falls; lost when every seat is gone ("ko").
The quest sets the ward with phase "ward1" (wind), "ward2" (earth) or "ward3" (water).
opts.quest: the quest whose lines the fight shows.
--]]

local Spirit = Encounter.define("QuestDirectorMan2g001")

local POOL_SPIRIT = 9205201
local POOL_GRINNAUX = 9290015
local POOL_HANDELOUP = 9290016
local POOL_TKEBBE = 9290017
local FIGHT_LEVEL = 13

local TIME_LIMIT_SECONDS = 1800
local FIRST_ASPECT_SECONDS = 25
local ASPECT_SECONDS = 32
local STRIKE_SECONDS = 8
local ALLY_STRIKE_DAMAGE = 120
local PLAYER_STRIKE_DAMAGE = 30
local CALL_REPEAT_SECONDS = 15
local CALL_TIMEOUT_SECONDS = 60
local REPLACEMENT_SECONDS = 10

local MOD_MINIMUM_HP_LOCK = 114
local MESSAGE_TYPE_SYSTEM = 32
local ACTIVE_STATE = 2
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_TIME_MINUTES = 25018
local TEXT_ASPECT_CHANGED = 265
local TEXT_PARTY_DEFEATED = 51147
local TEXT_MOB_ENGAGED = 30120
local TEXT_MOB_DEFEATED = 30121
local SPIRIT_DISPLAY_ID = 3105201

local ASPECT_WIND, ASPECT_EARTH, ASPECT_WATER = 1, 2, 3
local ASPECT_ORDER = { ASPECT_EARTH, ASPECT_WIND, ASPECT_WATER }
local ASPECT_NAMES = { [ASPECT_WIND] = "wind", [ASPECT_EARTH] = "earth", [ASPECT_WATER] = "water" }

local SPIRIT_POST = { -2017.339, -11.072, -947.748, 0.039 }
local SEATS = {
	{ pool = POOL_GRINNAUX, post = { -2009.278, -11.894, -931.778, -2.419 }, reserve = { -2010.0, -11.7, -919.0, -2.8 } },
	{ pool = POOL_HANDELOUP, post = { -2008.337, -11.846, -933.208, -2.243 }, reserve = { -2012.0, -11.7, -919.5, -2.8 } },
	{ pool = POOL_TKEBBE, post = { -2007.933, -11.759, -935.472, -1.849 }, reserve = { -2014.0, -11.7, -920.0, -2.8 } },
}

local SPIRIT_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }
local ARCHER_PROFILE = { behaviors = { Follow = false } }

function Spirit:setup(opts)
	self.quest = opts.quest
	self.player = self:participants()[1]
	self.ward, self.aspect, self.aspectIndex = 0, 0, 0
	self:timeLimit(TIME_LIMIT_SECONDS)
	self.spirit = self:spawn("spirit", { pool = POOL_SPIRIT, level = FIGHT_LEVEL, at = SPIRIT_POST, profile = SPIRIT_PROFILE })
	if self.spirit then self.spirit.cs:ChangeState(ACTIVE_STATE) end
	self.seats = {}
	for i, seat in ipairs(SEATS) do
		self.seats[i] = { npc = self:spawnArcher(seat.pool, seat.post), reserveUsed = false }
	end
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

for ward = 1, 3 do
	Spirit["phase_ward" .. ward] = function(self) self.ward = ward end
end

function Spirit:spawnArcher(pool, at)
	local ally = self:spawn("archers", { pool = pool, kind = "Ally", level = FIGHT_LEVEL, at = at, profile = ARCHER_PROFILE })
	if ally then ally.cs:ChangeState(ACTIVE_STATE) end
	return ally
end

-- Text 266 is name-first and no message here carries the player's name.
function Spirit:wardCall()
	local p = self.player.cs
	p:SendMessage(MESSAGE_TYPE_SYSTEM, "", p.DisplayName .. ", pray come to me!")
end

-- Live archers keep the spirit engaged; returns how many seats are still in play.
function Spirit:keepSeats()
	local now = self:elapsed()
	local inPlay = 0
	for i, seat in ipairs(self.seats) do
		if seat.npc and seat.npc:isAlive() then
			inPlay = inPlay + 1
			seat.downAt = nil
			if not seat.npc:isEngaged() then seat.npc:engage(self.spirit) end
		elseif not seat.reserveUsed then
			inPlay = inPlay + 1
			if seat.downAt == nil then
				seat.downAt = now
			elseif now - seat.downAt >= REPLACEMENT_SECONDS then
				seat.reserveUsed = true
				seat.npc = self:spawnArcher(SEATS[i].pool, SEATS[i].reserve)
				if seat.npc then seat.npc:engage(self.spirit) end
			end
		end
	end
	return inPlay
end

function Spirit:turnAspect()
	local now = self:elapsed()
	self.aspectIndex = (self.aspectIndex % #ASPECT_ORDER) + 1
	self.aspect = ASPECT_ORDER[self.aspectIndex]
	self.nextAspect = now + ASPECT_SECONDS
	self.nextStrike = now + STRIKE_SECONDS
	-- No game message names an element.
	self.player.cs:SendMessage(MESSAGE_TYPE_SYSTEM, "", "The elemental's aspect changes to " .. ASPECT_NAMES[self.aspect] .. ".")
	if self.quest then self:tell(self.quest, TEXT_ASPECT_CHANGED) end
	self:wardCall()
	self.callSince, self.lastCall = now, now
end

function Spirit:tick()
	local p = self.player.cs
	local now = self:elapsed()
	if not self.spirit:isAlive() then
		self:win("cleared")
		return false
	end
	if self:keepSeats() == 0 then
		p:SendGameMessage(GetWorldMaster(), TEXT_PARTY_DEFEATED, 0x20)
		self:fail("ko")
		return false
	end
	if self.nextAspect == nil and self.spirit:isEngaged() then
		self.nextAspect = now + FIRST_ASPECT_SECONDS
		p:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_ENGAGED, 0x20, SPIRIT_DISPLAY_ID)
	end
	if self.nextAspect ~= nil and now >= self.nextAspect then self:turnAspect() end

	if self.callSince ~= nil then
		if self.ward == self.aspect or now - self.callSince >= CALL_TIMEOUT_SECONDS then
			self.callSince = nil
		elseif now - self.lastCall >= CALL_REPEAT_SECONDS then
			self.lastCall = now
			self:wardCall()
		end
	end

	if self.aspect ~= 0 and self.nextStrike ~= nil and now >= self.nextStrike then
		self.nextStrike = now + STRIKE_SECONDS
		if self.ward ~= self.aspect then
			for _, seat in ipairs(self.seats) do
				if seat.npc and seat.npc:isAlive() then seat.npc.cs:DelHP(ALLY_STRIKE_DAMAGE) end
			end
			p:DelHP(PLAYER_STRIKE_DAMAGE)
		end
	end
end

function Spirit:onStart()
	if self.player == nil or self.spirit == nil then return end
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:tell(nil, TEXT_TIME_MINUTES, TIME_LIMIT_SECONDS / 60)
	self:every(1, function() return self:tick() end)
end

function Spirit:onEnd(result)
	if result == "win" and self.player then
		self.player.cs:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_DEFEATED, 0x20, SPIRIT_DISPLAY_ID)
	end
end

return Spirit
