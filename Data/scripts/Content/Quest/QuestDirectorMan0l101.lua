--[[
Man0l1 escort (director QuestDirectorMan0l101): bring Sisipu to Oschon's Torch while ankle biters
wait along the road. Lost if she falls or time runs out; won when the player reaches the torch with
no foe close by or fighting. After each wave Sisipu's line follows how she came through it; on the
road she guides or chides.
--]]

local Escort = Encounter.define("QuestDirectorMan0l101")

local POOL_SISIPU, POOL_ANKLE_BITER = 9290007, 9205603
local ESCORT_LEVEL = 5
local TIME_LIMIT = 1800
local HOLD_RADIUS, ARRIVAL_RADIUS, PLAYER_LEASH = 28, 20, 15
local DIALOGUE_SECONDS = 20
local HURT_HP_RATIO, CLOSE_HP_RATIO = 0.5, 0.85
local TORCH = { 137.44, 0, 1322.0 }
local MOD_MINIMUM_HP_LOCK = 114

local SISIPU_DISPLAY_ID, ANKLE_BITER_DISPLAY_ID = 1500024, 3205603
local TEXT_PROTECT_FROM_HARM, TEXT_TIME_MINUTES = 51005, 25018
local TEXT_MOB_ENGAGED, TEXT_MOB_DEFEATED = 30120, 30121
local TEXT_DUTY_START, TEXT_GUIDANCE, TEXT_DAWDLE = 105, 283, 285
local TEXT_WAVE_CLEAN, TEXT_WAVE_CLOSE, TEXT_WAVE_THANKS, TEXT_SISIPU_HURT, TEXT_ARRIVAL = 286, 287, 288, 289, 290

local SISIPU_START = { -60.25, 33.15, 162.51, 0.8 }
local ANKLE_BITERS = {
	{ 112.30, 47.20, 148.17 }, { 129.15, 44.25, 291.87 }, { 69.96, 41.22, 449.76 }, { 134.69, 52.41, 597.19 },
	{ 74.46, 61.65, 741.17 }, { -2.35, 53.43, 878.18 }, { 48.45, 43.43, 1038.45 }, { 124.43, 46.40, 1205.66 },
}

local function flat(a, x, z)
	local p = a:pos()
	return math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2)
end

function Escort:setup(opts)
	self.quest = opts.quest
	self.player = self:participants()[1]
	self:timeLimit(TIME_LIMIT)
	self.sisipu = self:spawn("escorts", { pool = POOL_SISIPU, kind = "Ally", level = ESCORT_LEVEL, at = SISIPU_START,
		profile = "Content/Profiles/EscortedChild", override = { bb = { leader = self.player } } })
	for _, b in ipairs(ANKLE_BITERS) do
		self:spawn("biters", { pool = POOL_ANKLE_BITER, level = self:int(5, 7), at = b })
	end
	self:objective("escorts", Objective.protect("escorts", 1), { fails = true })
	self:objective("torch", Objective.custom(function() return self:arrived() end), { wins = true })
	if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Escort:say(textId)
	if self.quest then self:tell(self.quest, textId) end
end

function Escort:foesNear()
	local n, engaged = 0, false
	for _, mob in ipairs(self:group("biters"):list()) do
		if mob:isAlive() then
			if mob:distance(self.player) <= HOLD_RADIUS or (self.sisipu and mob:distance(self.sisipu) <= HOLD_RADIUS) then
				n = n + 1
			end
			engaged = engaged or mob:isEngaged()
		end
	end
	return n, engaged
end

function Escort:arrived()
	if self.player == nil then return false end
	local near, engaged = self:foesNear()
	return near == 0 and not engaged and flat(self.player, TORCH[1], TORCH[3]) <= ARRIVAL_RADIUS
end

function Escort:onStart()
	local p = self.player
	if p then
		p.cs:SendGameMessage(GetWorldMaster(), TEXT_PROTECT_FROM_HARM, 0x20, SISIPU_DISPLAY_ID)
		p.cs:SendGameMessage(GetWorldMaster(), TEXT_TIME_MINUTES, 0x20, TIME_LIMIT / 60)
	end
	self:say(TEXT_DUTY_START)

	local lastNear, lastDialogue, fought, tick = 0, 0, false, 0
	self:every(1, function()
		local sisipu = self.sisipu
		if not (p and sisipu and sisipu:isAlive()) then return false end
		tick = tick + 1
		local near, engaged = self:foesNear()
		fought = fought or sisipu:isEngaged()
		if near == 0 and lastNear > 0 then
			local ratio = sisipu:hp() / math.max(1, sisipu:maxHp())
			if ratio <= HURT_HP_RATIO then
				self:say(TEXT_SISIPU_HURT)
			elseif ratio <= CLOSE_HP_RATIO then
				self:say(TEXT_WAVE_CLOSE)
			else
				self:say(fought and TEXT_WAVE_THANKS or TEXT_WAVE_CLEAN)
			end
			fought = false
			lastDialogue = tick
		end
		lastNear = near
		if near == 0 and not engaged and tick - lastDialogue >= DIALOGUE_SECONDS then
			lastDialogue = tick
			self:say(sisipu:distance(p) > PLAYER_LEASH and TEXT_DAWDLE or TEXT_GUIDANCE)
		end
	end)

	self:on("Engaged", { group = "biters" }, function()
		if p then p.cs:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_ENGAGED, 0x20, ANKLE_BITER_DISPLAY_ID) end
	end)
	self:on("Died", { group = "biters" }, function()
		if p then p.cs:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_DEFEATED, 0x20, ANKLE_BITER_DISPLAY_ID) end
	end)
end

function Escort:onEnd(result)
	if result == "win" then self:say(TEXT_ARRIVAL) end
end

return Escort
