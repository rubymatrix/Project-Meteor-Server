--[[
Story allies in the opening battles (client classes FighterAllyOpening*): hold their places,
draw weapons and close in when the player does, strike once the player's foe has been hit, and
stay where the fight left them.
Spells and caster range come from the encounter, by each ally's class.
--]]
return Profile.define {
    behaviors = {
        Follow = false,
        Ready = { leader = "leader" },
        Assist = { leader = "leader", onlyWhenAttacked = true },
        Combat = { pickInterval = 2 },
    },
}
