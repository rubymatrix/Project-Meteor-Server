--[[
Dzemael Darkhold's warden, child of RaidRoc0Dungeon01: a cone cleave every 15 s; below half he
calls two bats and cleaves every 9 s; at 6 minutes a room-wide enrage.
--]]

local Warden = Encounter.define("RaidRoc0Dungeon01Warden")

local POOL_WARDEN, POOL_BAT = 9300014, 9300010
local CENTRE = { 16.2, 173.9, 98.0 }

function Warden:setup()
	self:arena({ circle = { centre = CENTRE, radius = 16 }, out = "push" })
	self.boss = self:spawn("boss", { pool = POOL_WARDEN, level = 27, hp = 9000, at = { 19.8, 173.9, 93.0 },
		profile = { behaviors = { Roam = false, Leash = { radius = 0 } } } })
	self:objective("warden", Objective.kill("boss"), { wins = true })
end

function Warden:onStart()
	self:goto("p1")
	self:after(360, function()
		self:hazard({ circle = { centre = CENTRE, radius = 30 }, delay = 5, percent = 200, source = self.boss, name = "enrage" })
	end)
end

function Warden:cleave()
	local t = self.boss:target()
	if not t then return end
	self.boss:face(t)
	self:hazard({ cone = { on = self.boss, radius = 10, angle = 90 }, delay = 3, damage = 400, source = self.boss, name = "cleave" })
end

function Warden:phase_p1()
	self:onHp(self.boss, 50, function() self:goto("p2") end)
	self:every(15, function() self:cleave() end)
end

function Warden:phase_p2()
	self:spawnGroup({ { at = { 11.5, 173.8, 95.1 } }, { at = { 16.2, 173.9, 101.9 } } }, { pool = POOL_BAT, level = 25, group = "adds" })
	self:every(9, function() self:cleave() end)
end

return Warden
