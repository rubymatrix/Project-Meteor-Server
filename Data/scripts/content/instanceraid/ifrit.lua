--[[
The Bowl of Embers: Ifrit, one mechanics module for the Lesser, Normal and Hyper directors. Sear and
Eruption in p1; at the HP line he holds the centre for the nails and Hellfire grows the longer they
live; p2 is faster, with Radiant Plume on Hyper. Numbers are placeholders.
--]]

local Ifrit = ContentArea.define("ifrit")

-- The content area and director each client director variant runs in.
function Ifrit.areaFor(director)
    return {
        zone = 240,
        classPath = "/Area/PrivateArea/Occupancy/RaidDungeonSimple",
        name = director:sub(1, 1):lower() .. director:sub(2),
        script = "SimpleContentOccupancy",
        director = "InstanceRaid/" .. director,
    }
end
Ifrit.entry = { 2508.8, 247.0, 2211.2, 1.56 }

local CENTRE = { 2526.60, 248.34, 2208.06 }
local BOSS_AT = { 2542.4, 248.5, 2213.5 }
local NAIL_OFFSETS = { { 0.6, -11.0 }, { 0.2, 11.1 }, { -11.5, -2.0 }, { 13.3, -1.8 } }
local POOL_IFRIT, POOL_NAIL = 9300020, 9300021

Ifrit:variant("lesser", {
    level = 27, hp = 7500, nailHp = 700, nails = 2, nailsAt = 40,
    sear = { 8, 11 }, searFast = { 6, 8 }, searDamage = 320,
    eruptions = 1, eruptionsLate = 2, eruptDamage = 260,
    hellfirePercent = 45, hellfireCap = 75, plume = false, timeLimit = 1800,
})

Ifrit:variant("normal", {
    level = 52, hp = 22000, nailHp = 1600, nails = 4, nailsAt = 50,
    sear = { 6, 9 }, searFast = { 4, 5 }, searDamage = 900,
    eruptions = 1, eruptionsLate = 3, eruptDamage = 700,
    hellfirePercent = 60, hellfireCap = 60, plume = false, timeLimit = 1800,
})

Ifrit:variant("hyper", {
    level = 55, hp = 30000, nailHp = 2600, nails = 4, nailsAt = 60,
    sear = { 5, 7 }, searFast = { 3, 4 }, searDamage = 1300,
    eruptions = 2, eruptionsLate = 4, eruptDamage = 1000,
    hellfirePercent = 85, hellfireCap = 45, plume = true, timeLimit = 1800,
})

local function at(dx, dz)
    return { CENTRE[1] + dx, CENTRE[2], CENTRE[3] + dz }
end

function Ifrit:setup()
    local c = self.cfg
    self:timeLimit(c.timeLimit)
    self:arena({ circle = { centre = CENTRE, radius = 22 }, out = "push" })
    self.boss = self:spawn("boss", { pool = POOL_IFRIT, level = c.level, hp = c.hp, at = BOSS_AT,
        profile = { behaviors = { Roam = false, Leash = { radius = 0 }, Detect = {} },
                    senses = { proximity = { range = 30 } } } })
    self:objective("ifrit", Objective.kill("boss"), { wins = true })
end

function Ifrit:onStart()
    self:goto("p1")
end

function Ifrit:sear()
    local t = self.boss:target()
    if not t then return end
    self.boss:push("Mechanic", { steps = { { face = "target", wait = 1 } } })
    self:hazard({ cone = { on = self.boss, radius = 12, angle = 100 }, delay = 2, damage = self.cfg.searDamage, source = self.boss, name = "sear" })
end

function Ifrit:eruptions(n)
    for _, p in ipairs(self:pick(n)) do
        local pos = p:pos()
        self:hazard({ circle = { centre = { pos.x, pos.y, pos.z }, radius = 4 }, delay = 3, damage = self.cfg.eruptDamage, source = self.boss, name = "eruption" })
    end
end

function Ifrit:plume()
    for _, d in ipairs({ { 0, 7 }, { 0, -7 }, { 14, 0 }, { -14, 0 } }) do
        self:hazard({ circle = { centre = at(d[1], d[2]), radius = 5 }, delay = 4, damage = self.cfg.eruptDamage, source = self.boss, name = "plume" })
    end
end

function Ifrit:phase_p1()
    local c = self.cfg
    self:onHp(self.boss, c.nailsAt, function() self:goto("nails") end)
    self:every(function() return self:roll(c.sear) end, function() self:sear() end)
    self:every(14, function() self:eruptions(c.eruptions) end)
end

function Ifrit:phase_nails()
    local c = self.cfg
    local hold = self.boss:push("Mechanic", { steps = { { go = CENTRE, pace = "run" }, { face = 0, hold = true } } }, { duration = c.hellfireCap + 6 })
    local specs = {}
    for i = 1, c.nails do
        local o = NAIL_OFFSETS[i]
        table.insert(specs, { at = at(o[1], o[2]) })
    end
    local nails = self:spawnGroup(specs, { pool = POOL_NAIL, level = c.level, hp = c.nailHp, group = "nails",
        profile = "ai/kinds/structure", faction = "Monster", tags = { "add" } })
    local started = self:elapsed()
    local cleared = waitUntil(function() return nails:alive() == 0 end, c.hellfireCap)
    local slow = math.min(1, (self:elapsed() - started) / c.hellfireCap)
    self:hazard({ circle = { centre = CENTRE, radius = 40 }, delay = 2, percent = c.hellfirePercent * (cleared and (0.6 + 0.4 * slow) or 1.5),
        source = self.boss, name = "hellfire" })
    wait(3)
    self.boss:remove(hold)
    self:goto("p2")
end

function Ifrit:phase_p2()
    local c = self.cfg
    self:every(function() return self:roll(c.searFast) end, function() self:sear() end)
    self:every(12, function() self:eruptions(c.eruptionsLate) end)
    if c.plume then self:every(25, function() self:plume() end) end
end

return Ifrit
