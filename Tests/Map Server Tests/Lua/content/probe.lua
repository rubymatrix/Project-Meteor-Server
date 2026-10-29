-- Test content: phases, waits, triggers, counters, objectives, profiles and hazards.
local Probe = Encounter.define("probe")

Probe:variant("two", { hits = 2 })
Probe:variant("led", { ledByFoe = true })

function Probe:setup(opts)
    self.log = {}
    self.foe = self:spawn("foes", { pool = 1, level = 5, at = { 0, 0, 0 },
        profile = { behaviors = { Roam = false, Detect = false }, tags = { "target" } } })
    self.friend = self:spawn("friends", { pool = 1, kind = "ally", level = 5, at = { 30, 0, 0 },
        override = self.cfg.ledByFoe and { bb = { leader = self.foe } } or nil })
    self:objective("hits", Objective.count("hits", self.cfg.hits or 3), { wins = true })
end

function Probe:onStart()
    table.insert(self.log, "start")
    self:goto("one")
end

function Probe:phase_one()
    self:counter("hits", 1)
    wait(2)
    table.insert(self.log, "waited")
    self:goto("two")
end

function Probe:phase_two()
    self:on("Signal", { name = "poke" }, function()
        table.insert(self.log, "poked")
        self:counter("hits", 1)
    end)
    self:hazard({ circle = { centre = { 0, 0, 0 }, radius = 3 }, delay = 0.2, damage = 7, hits = "all", name = "burn",
        onResolve = function(hits) table.insert(self.log, "burn" .. #hits) end })
    wait(0.5)
    self:signal("poke")
end

function Probe:onEnd(result, reason)
    table.insert(self.log, "end:" .. result .. ":" .. reason)
end

function Probe:report()
    return table.concat(self.log, ",")
end

return Probe
