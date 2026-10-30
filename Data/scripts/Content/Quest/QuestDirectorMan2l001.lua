--[[
Never the Twain Shall Meet (Man2l0 SEQ_020), director QuestDirectorMan2l001: the deck duel.
Emerick and Merodaulyn idle until the player attacks one, then fight each other; the first down
loses and counter "winner" names the survivor. The player keeps 1 HP.
--]]

local Duel = Encounter.define("QuestDirectorMan2l001")

local POOL_EMERICK = 9290011
local POOL_MERODAULYN = 9290012
local DUEL_LEVEL = 13
local TIME_LIMIT_SECONDS = 1800
local IDLE_START_SECONDS = 60

local MOD_MINIMUM_HP_LOCK = 114
local ACTIVE_STATE, PASSIVE_STATE = 2, 0
local TEXT_BOUND_BY_DUTY = 50011

local EMERICK_POST = { 1823.832, 16.352, 1841.809, 0.004 }
local MERODAULYN_POST = { 1823.838, 16.352, 1843.863, -3.137 }

local WINNER_EMERICK = 1
local WINNER_MERODAULYN = 2

-- Each duelist is its own faction so the two can fight each other.
local function duelistProfile(faction)
	return { faction = faction, behaviors = { Roam = false, Detect = false, Link = false } }
end

function Duel:setup()
	self.player = self:participants()[1]
	self:timeLimit(TIME_LIMIT_SECONDS)
	for _, f in ipairs({ "Emerick", "Merodaulyn" }) do
		self:relate(f, "Player", "hostile")
		self:relate(f, "PlayerAlly", "hostile")
	end
	self:relate("Emerick", "Merodaulyn", "hostile")
	self.emerick = self:spawn("duelists", { pool = POOL_EMERICK, level = DUEL_LEVEL, at = EMERICK_POST,
		profile = duelistProfile("Emerick") })
	self.merodaulyn = self:spawn("duelists", { pool = POOL_MERODAULYN, level = DUEL_LEVEL, at = MERODAULYN_POST,
		profile = duelistProfile("Merodaulyn") })
	for _, d in ipairs({ self.emerick, self.merodaulyn }) do
		if d then d.cs:ChangeState(ACTIVE_STATE) end
	end
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

local function keepOn(a, b)
	if not a:isEngaged() then a:engage(b) end
end

function Duel:startFight(attacked, other)
	self.fighting = true
	other:engage(attacked)
	attacked:engage(other)
end

function Duel:tick()
	local e, m = self.emerick, self.merodaulyn
	local emerickUp, merodaulynUp = e:isAlive(), m:isAlive()
	if emerickUp ~= merodaulynUp then
		local survivor = emerickUp and e or m
		self:counter("winner", emerickUp and WINNER_EMERICK or WINNER_MERODAULYN)
		survivor.cs:ChangeState(PASSIVE_STATE)
		if self.player then self.player.cs:SetHP(self.player.cs:GetMaxHP()) end
		self:win("duel")
		return false
	elseif not emerickUp then
		self:fail("script")
		return false
	end

	if not self.fighting then
		if e:isEngaged() then
			self:startFight(e, m)
		elseif m:isEngaged() then
			self:startFight(m, e)
		elseif self:elapsed() >= IDLE_START_SECONDS then
			self:startFight(e, m)
		end
	else
		keepOn(e, m)
		keepOn(m, e)
	end
end

function Duel:onStart()
	if self.emerick == nil or self.merodaulyn == nil then return end
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:every(1, function() return self:tick() end)
end

return Duel
