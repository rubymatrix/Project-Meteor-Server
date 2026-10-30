--[[
Quest battles: a player against a few foes in a quest content area, sometimes with an ally. Class
quest bouts and the Grand Company and company quest fights. A director's file picks its variant:
return require("Content/Quest/QuestBattle"):as("Gla20001"). Variant fields and the fight's rules
are in Data/Docs/Scripts/Content/Quest/QuestBattle.md.
--]]

local QuestBattle = Encounter.define("QuestBattle")

local MOD_MINIMUM_HP_LOCK = 114
local MESSAGE_TYPE_SYSTEM = 32
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_DEFEAT_ENEMY_GROUP = 51003
local TEXT_TIME_MINUTES = 25018
local ENGAGE_DELAY_SECONDS = 3
local WAVE_DELAY_SECONDS = 3
local TIME_LIMIT_SECONDS = 1800

QuestBattle:variant("Arc20001", {
	level = 15,
	defeat = true,
	waves = {
		{
			{ 8205503, -1362.240, 31.527, -2110.540, 0.0 },
			{ 8205503, -1350.240, 31.527, -2110.540, 0.0 },
			{ 8205504, -1362.240, 31.527, -2098.540, 0.0 },
			{ 8205504, -1350.240, 31.527, -2098.540, 0.0 },
			{ 8205505, -1356.240, 31.527, -2095.540, 0.0 },
		},
	},
})

QuestBattle:variant("Cnj20001", {
	level = 15,
	defeat = true,
	waves = {
		{ { 8201408, 726.000, 31.795, -858.000, 0.0 } },
		{ { 8201408, 726.000, 31.795, -858.000, 0.0 } },
		{ { 8201408, 726.000, 31.795, -858.000, 0.0 } },
		{ { 8201408, 726.000, 31.795, -858.000, 0.0 } },
		{ { 8201409, 726.000, 31.795, -858.000, 0.0, 17 } },
	},
})

QuestBattle:variant("Cnj30001", {
	level = 25,
	defeat = true,
	waves = {
		{
			{ 8204601, -549.790, 5.0, -519.350, 0.0 },
			{ 8204701, -547.290, 5.0, -520.850, 0.0 },
			{ 8204801, -544.790, 5.0, -521.350, 0.0 },
			{ 8204901, -542.790, 5.0, -521.350, 0.0 },
			{ 8205001, -540.290, 5.0, -520.850, 0.0 },
			{ 8205101, -537.790, 5.0, -519.350, 0.0 },
		},
	},
})

QuestBattle:variant("Exc20001", {
	level = 15,
	defeat = { { 3204003, 6 } },
	timeNotice = true,
	waves = {
		{
			{ 8204003, -803.860, 45.000, -679.740, 0.000 },
			{ 8204003, -791.860, 45.000, -679.740, 0.000 },
			{ 8204003, -803.860, 45.000, -667.740, 0.000 },
			{ 8204003, -791.860, 45.000, -667.740, 0.000 },
			{ 8204003, -806.860, 45.000, -673.740, 0.000 },
			{ 8204003, -788.860, 45.000, -673.740, 0.000 },
		},
		{
			{ 8204003, -797.860, 45.000, -664.740, 0.000 },
			{ 8204003, -803.860, 45.000, -679.740, 0.000 },
			{ 8204004, -797.860, 45.000, -685.740, 0.000, 20 },
		},
	},
})

QuestBattle:variant("Gla20001", {
	level = 20,
	hpLock = true,
	waveDelay = 2,
	waves = { { { 8289006, -187.225, 190.150, 225.730, 3.142 } } },
})

QuestBattle:variant("Gla30001", {
	level = 30,
	hpLock = true,
	waveDelay = 2,
	waves = { { { 8289009, 195.040, 27.900, -1591.100, -0.150 } } },
})

QuestBattle:variant("Gla30601", {
	level = 36,
	hpLock = true,
	waveDelay = 2,
	waves = { { { 8289010, -187.225, 190.150, 225.730, 3.142 } } },
})

QuestBattle:variant("Gla30602", {
	level = 36,
	hpLock = true,
	waveDelay = 2,
	waves = { { { 8289011, -187.225, 190.150, 225.730, 3.142 } } },
})

QuestBattle:variant("Lnc20001", {
	level = 15,
	hpLock = true,
	waveDelay = 2,
	defeat = { { 3205605, 4 } },
	waves = {
		{
			{ 8205605, -649.270, 20.217, -1067.140, 0.000 },
			{ 8205605, -637.270, 20.217, -1067.140, 0.000 },
			{ 8205605, -649.270, 20.217, -1055.140, 0.000 },
			{ 8205605, -637.270, 20.217, -1055.140, 0.000 },
		},
	},
})

QuestBattle:variant("Lnc30001", {
	level = 30,
	hpLock = true,
	waveDelay = 2,
	defeat = { { 3200108, 5 }, { 3200304, 2 } },
	waves = {
		{
			{ 8200108, 371.700, 6.188, -22.300, 0.000 },
			{ 8200108, 387.700, 6.188, -22.300, 0.000 },
			{ 8200108, 371.700, 6.188, -6.300, 0.000 },
			{ 8200108, 387.700, 6.188, -6.300, 0.000 },
			{ 8200108, 379.700, 6.188, -26.300, 0.000 },
		},
		{
			{ 8200304, 373.700, 6.188, -14.300, 0.000 },
			{ 8200304, 385.700, 6.188, -14.300, 0.000 },
		},
	},
})

QuestBattle:variant("Lnc30601", {
	level = 36,
	hpLock = true,
	waveDelay = 2,
	defeat = { { 3205202, 1 } },
	waves = { { { 8205202, 394.230, 5.455, -790.400, 0.000 } } },
})

QuestBattle:variant("Pgl30001", {
	level = 28,
	timeNotice = true,
	waves = {
		{
			{ 8280217, -421.000, 41.200, 452.000, 3.142 },
			{ 8280217, -419.000, 41.200, 452.000, 3.142 },
			{ 8280217, -417.000, 41.200, 452.000, 3.142 },
			{ 8280217, -415.000, 41.200, 452.000, 3.142 },
			{ 8280217, -413.000, 41.200, 452.000, 3.142 },
		},
	},
})

QuestBattle:variant("Pgl30601", {
	level = 36,
	timeNotice = true,
	allies = { { 8290022, -1385.260, 56.000, 302.200, 0.000 } },
	waves = {
		{
			{ 8289014, -1389.260, 56.000, 310.200, 3.142 },
			{ 8289014, -1385.260, 56.000, 310.200, 3.142 },
		},
	},
})

QuestBattle:variant("Thm30001", {
	level = 30,
	timeNotice = true,
	foesOpenOnAlly = true,
	defeat = { { 3201603, 1 } },
	allies = { { 8290023, -488.716, 45.882, -379.102, 0.000 } },
	waves = { { { 8201603, -494.716, 45.882, -393.102, 0.000 } } },
})

QuestBattle:variant("Com0g101", { level = 24, waves = { { { 2209901, 1196.360, 0.040, 1090.580, 3.842 } } } })

QuestBattle:variant("Com0g401", {
	level = 22,
	waves = {
		{
			{ 100273, -636.610, 18.090, -2031.650, 0.782 },
			{ 100269, -640.000, 19.500, -2028.000, 0.782 },
			{ 100274, -633.000, 16.800, -2035.000, 0.782 },
		},
	},
})

QuestBattle:variant("Com0g501", { level = 26, waves = { { { 100233, 1605.010, 0.080, 1275.280, 3.902 } } } })

QuestBattle:variant("Com0g601", {
	level = 25,
	waves = {
		{
			{ 100047, 1502.100, 20.930, -778.200, 5.432 },
			{ 100047, 1505.000, 20.620, -782.000, 5.432 },
			{ 100091, 1508.000, 21.000, -776.000, 5.432 },
		},
	},
})

QuestBattle:variant("Com0l101", { level = 24, waves = { { { 100210, 1531.060, 61.490, -1261.420, 5.612 } } } })

QuestBattle:variant("Com0l401", {
	level = 22,
	waves = {
		{
			{ 100273, 987.900, 64.910, -1570.700, 5.502 },
			{ 100269, 986.450, 65.100, -1562.600, 5.502 },
			{ 100274, 985.400, 64.190, -1573.200, 5.502 },
		},
	},
})

QuestBattle:variant("Com0l501", {
	level = 25,
	waves = {
		{
			{ 100383, 673.000, 49.930, -610.000, 5.502 },
			{ 100207, 676.000, 49.440, -606.000, 5.502 },
			{ 100383, 670.570, 50.890, -612.340, 5.502 },
		},
	},
})

QuestBattle:variant("Com0l601", {
	level = 25,
	waves = {
		{
			{ 100273, -2193.000, 14.040, -429.000, 0.782 },
			{ 100270, -2195.000, 13.980, -425.000, 0.782 },
			{ 100272, -2190.000, 14.140, -431.000, 0.782 },
		},
	},
})

QuestBattle:variant("Com0u101", {
	level = 24,
	waves = {
		{ { 100374, -1720.335, 55.770, 97.961, 2.412, classPath = "/Chara/Npc/Monster/Raptor/RaptorForestQuestCom0u1" } },
	},
})

QuestBattle:variant("Com0u401", {
	level = 23,
	waves = {
		{
			{ 100383, 1151.499, 311.700, -959.325, 0.712 },
			{ 100207, 1148.470, 311.700, -956.713, 0.712 },
			{ 2280105, 1145.440, 311.700, -954.101, 0.712 },
		},
	},
})

QuestBattle:variant("Com0u501", {
	level = 26,
	waves = {
		{
			{ 2280203, -2170.826, 14.250, -420.055, 3.442 },
			{ 2280207, -2167.005, 14.250, -421.237, 3.442 },
			{ 2280211, -2163.183, 14.250, -422.419, 3.442 },
		},
	},
})

QuestBattle:variant("Com0u601", {
	level = 27,
	waves = {
		{ { 8280157, -1584.826, 55.720, 252.967, 3.942, classPath = "/Chara/Npc/Monster/Fighter/FighterEnemyGladiatorCharledore" } },
	},
})

QuestBattle:variant("Com5Visit", { winOnClear = false, waves = {} })

QuestBattle:variant("Gcg10201", {
	level = 40,
	waves = {
		{
			{ 100273, 1631.366, 45.100, -795.380, 1.942 },
			{ 100270, 1632.816, 45.100, -791.652, 1.942 },
			{ 100274, 1634.265, 45.100, -787.924, 1.942 },
		},
	},
})

QuestBattle:variant("Gcg10301", { level = 45, waves = { { { 100309, -1567.129, -11.000, -531.651, 6.042 } } } })

QuestBattle:variant("Gcl10201", {
	level = 40,
	waves = {
		{
			{ 100273, -517.000, 71.720, -2439.000, 0.782 },
			{ 100270, -519.000, 70.660, -2433.000, 0.782 },
			{ 100274, -513.000, 72.260, -2441.000, 0.782 },
		},
	},
})

QuestBattle:variant("Gcl10301", { level = 45, waves = { { { 100309, -1404.508, 3.490, -603.440, 2.342 } } } })

QuestBattle:variant("Gcl10501", {
	level = 45,
	waves = {
		{
			{ 100238, -509.683, -4.790, 355.313, 0.162 },
			{ 100235, -513.631, -4.790, 355.956, 0.162 },
			{ 100239, -517.579, -4.790, 356.600, 0.162 },
		},
	},
})

QuestBattle:variant("Gcu10201", {
	level = 41,
	waves = {
		{
			{ 100269, 50.000, 205.330, -386.000, 3.142, classPath = "/Chara/Npc/Monster/Empire/EmpireChiefQuestGcu102" },
			{ 100273, 46.000, 205.330, -390.000, 3.142 },
			{ 100270, 54.000, 205.330, -390.000, 3.142 },
		},
	},
})

QuestBattle:variant("Gcu10301", {
	level = 46,
	waves = {
		{ { 100309, -1519.000, 49.000, -139.989, 1.572, classPath = "/Chara/Npc/Monster/Killermachine/KillermachineLesserGcx103" } },
	},
})

QuestBattle:variant("Thm20001", {
	timeNotice = true,
	waveDelay = 0,
	defeat = { { 3102313, 5 } },
	waves = {
		{
			{ 8102313, -1235.530, 57.000, -316.290, 0.000, level = 15 },
			{ 8102313, -1223.530, 57.000, -316.290, 0.000, level = 15 },
			{ 8102313, -1235.530, 57.000, -304.290, 0.000, level = 15 },
			{ 8102313, -1223.530, 57.000, -304.290, 0.000, level = 15 },
			{ 8102313, -1229.530, 57.000, -301.290, 0.000, level = 15 },
		},
		{ { 8202303, -1229.530, 57.000, -319.290, 0.000, level = 15, count = "billygoat" }, joinAt = 1 },
		{ { 8202307, -1229.530, 57.000, -318.290, 0.000, level = 20 } },
	},
})

QuestBattle:variant("Thm30601", {
	level = 36,
	timeNotice = true,
	settle = 2,
	defeat = { { 4000189, 1 } },
	waves = { { { 8289015, -1849.756, 24.922, -292.174, 0.000, yield = true } } },
})

local FOE_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }

local function at(e)
	return { e[2], e[3], e[4], e[5] or 0 }
end

local function spec(e, level)
	return { pool = e[1], level = e.level or level, at = at(e), classPath = e.classPath }
end

function QuestBattle:setup()
	local c = self.cfg
	self.player = self:participants()[1]
	self.waves = { unpack(c.waves) }
	self.winOnClear = c.winOnClear ~= false
	self.wave = 0
	self.yielders, self.yielded, self.counts = {}, {}, {}
	self:timeLimit(self.opts.timeLimit or c.timeLimit or TIME_LIMIT_SECONDS)
	for _, a in ipairs(c.allies or {}) do
		local s = spec(a, c.level)
		s.kind = "Ally"
		s.override = { bb = { leader = self.player } }
		self:spawn("allies", s)
	end
	if #self.waves > 0 then self:spawnWave(1) end
end

function QuestBattle:spawnWave(n)
	self.wave = n
	self.waveAt = self:elapsed()
	self.clearedAt = nil
	for _, e in ipairs(self.waves[n]) do
		local s = spec(e, self.cfg.level)
		s.profile = FOE_PROFILE
		local foe = self:spawn("foes", s)
		if foe ~= nil then
			if e.yield then
				foe.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
				self.yielders[foe.cs.Id] = foe
			end
			if e.count then self.counts[foe.cs.Id] = e.count end
		end
	end
end

-- Foes still fighting: alive and not yielded.
function QuestBattle:foesUp()
	local n = 0
	for _, foe in ipairs(self:group("foes"):list()) do
		local id = foe.cs.Id
		local y = self.yielders[id]
		if y ~= nil and foe:isAlive() and foe:hp() <= 1 then
			self.yielders[id] = nil
			self.yielded[id] = true
			foe:disengage()
			foe:push("Hold", {})
		end
		if foe:isAlive() and not self.yielded[id] then n = n + 1 end
	end
	return n
end

function QuestBattle:phase_reserve()
	if self.opts.reserve == nil then return end
	table.insert(self.waves, self.opts.reserve)
	self.winOnClear = true
	self:spawnWave(#self.waves)
end

function QuestBattle:target()
	if self.cfg.foesOpenOnAlly then
		local ally = self:group("allies"):first()
		if ally ~= nil and ally:isAlive() then return ally end
	end
	local player = self.player
	if player ~= nil and player:isAlive() then return player end
	return nil
end

function QuestBattle:sendFoes()
	if self:elapsed() - self.waveAt < (self.cfg.engageDelay or ENGAGE_DELAY_SECONDS) then return end
	local target = self:target()
	if target == nil then return end
	for _, foe in ipairs(self:group("foes"):list()) do
		local t = foe:target()
		if foe:isAlive() and not self.yielded[foe.cs.Id] and (not foe:isEngaged() or t == nil or not t:isAlive()) then
			foe:engage(target)
		end
	end
end

function QuestBattle:onStart()
	local c = self.cfg
	local player = self.player and self.player.cs
	if player ~= nil then
		if c.hpLock then player:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
		player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
		if c.defeat == true then
			player:SendGameMessage(GetWorldMaster(), TEXT_DEFEAT_ENEMY_GROUP, 0x20)
		elseif c.defeat then
			for _, d in ipairs(c.defeat) do
				player:SendGameMessage(GetWorldMaster(), TEXT_DEFEAT_ENEMY_GROUP, 0x20, d[1], d[2])
			end
		end
		if c.timeNotice then
			player:SendGameMessage(GetWorldMaster(), TEXT_TIME_MINUTES, 0x20, (c.timeLimit or TIME_LIMIT_SECONDS) / 60)
		end
	end
	self:on("Died", { group = "foes" }, function(_, ev)
		local name = self.counts[ev.actor.cs.Id]
		if name then self:counter(name, 1) end
	end)
	self:every(1, function()
		if c.hpLock and player ~= nil and player:GetHP() <= 1 then
			self:fail("ko")
			return false
		end
		local up = self:foesUp()
		local nextWave = self.waves[self.wave + 1]
		if nextWave ~= nil and up > 0 and up <= (nextWave.joinAt or 0) then
			self:spawnWave(self.wave + 1)
			up = self:foesUp()
		end
		if up > 0 then
			self:sendFoes()
			return
		end
		if not self.winOnClear then return end
		if not self.clearedAt then self.clearedAt = self:elapsed() end
		local waited = self:elapsed() - self.clearedAt
		if nextWave ~= nil then
			if waited >= (c.waveDelay or WAVE_DELAY_SECONDS) then self:spawnWave(self.wave + 1) end
		elseif waited >= (c.settle or 0) then
			self:win("cleared")
			return false
		end
	end)
end

function QuestBattle:onEnd(result, reason)
	for _, p in ipairs(self:participants()) do
		local player = p.cs
		if self.cfg.hpLock then
			player:SetMod(MOD_MINIMUM_HP_LOCK, 0)
			-- Pinned at 1 HP the client never plays its own KO line.
			if reason == "ko" then
				player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "You are defeated.")
				player:SetHP(player:GetMaxHP())
			end
		end
		if result == "win" and p:isDead() then player:Revive(100) end
	end
end

return QuestBattle
