--[[
Children under escort: follow their leader, never fight, flag damage taken as protected.
--]]
return Profile.define {
    tags = { "protected" },
    behaviors = {
        Follow = { leader = "leader", gap = 5, slot = "rear", catchUp = 8 },
        Assist = false,
        Combat = false,
        Avoid = false,
    },
}
