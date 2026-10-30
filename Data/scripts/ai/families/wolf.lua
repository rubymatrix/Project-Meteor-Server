--[[
Wolves hunt in packs: they hear well, link with any wolf close by and keep chasing longer.
--]]
return Profile.define {
    senses = { sound = { range = 12 } },
    behaviors = {
        Link  = { radius = 14, by = "family" },
        Leash = { radius = 60 },
    },
}
