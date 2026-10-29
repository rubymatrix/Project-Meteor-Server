--[[
Aleport's hamlet cycle: a supply stage, then a combat stage during which players can fight
HamletDefenseAleport. Survives restarts: the cycle and the tallies live in self.saved.
--]]

local Aleport = Campaign.define("HamletAleport")

local SUPPLY_HOURS, COMBAT_HOURS = 50, 25

function Aleport:start()
    self.saved.defended = self.saved.defended or 0
    self.saved.lost = self.saved.lost or 0
    self:cycle({ { "supply", SUPPLY_HOURS }, { "combat", COMBAT_HOURS } })
end

function Aleport:onCombatStage()
    log('info', 'Aleport: combat stage')
end

function Aleport:onSupplyStage()
    log('info', 'Aleport: supply stage')
end

-- Players enter the battle while the combat stage runs.
function Aleport:enter(player)
    if self:stage() ~= "combat" then return nil end
    return Content.launch("HamletDefenseAleport", "", nil, player.cs or player, {})
end

function Aleport:battleEnded(result, battle)
    if result == "win" then self.saved.defended = self.saved.defended + 1 else self.saved.lost = self.saved.lost + 1 end
    self:save()
end

return Aleport
