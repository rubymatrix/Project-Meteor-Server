--[[
Man0u1 first-round coliseum match (director QuestDirectorMan0u101). It can't be won: both sides keep
1 HP. The player pinned at 1 HP, the round running out or the gladiator gone all end it. No round
timer is known; ROUND_SECONDS keeps a stalled match from running forever.
--]]

local Match = Encounter.define("QuestDirectorMan0u101")

local POOL_TOURNEY_GLADIATOR = 8280157
local GLADIATOR_LEVEL = 5
local ROUND_SECONDS = 300
local GLADIATOR_POST = { -170.794, 174.984, 160.326, -1.58 }
local MOD_MINIMUM_HP_LOCK = 114

function Match:setup()
    self.player = self:participants()[1]
    self:timeLimit(ROUND_SECONDS)
    self.gladiator = self:spawn("gladiator", { pool = POOL_TOURNEY_GLADIATOR, level = GLADIATOR_LEVEL, at = GLADIATOR_POST,
        profile = { behaviors = { Roam = false, Detect = false, Leash = { radius = 0 } } } })
    if self.gladiator then self.gladiator.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
    self:objective("round", Objective.custom(function()
        local g = self.gladiator
        return self.player == nil or self.player:hp() <= 1 or g == nil or not g:isAlive()
    end), { wins = true })
    if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Match:onStart()
    if self.gladiator and self.player then self.gladiator:engage(self.player) end
end

function Match:onEnd()
    local g = self.gladiator
    if g and g:isAlive() then
        g:disengage()
        g.cs:ChangeState(0)
    end
end

return Match
