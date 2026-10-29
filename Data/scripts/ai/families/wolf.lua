-- Wolves hunt in packs: they hear well, link with any wolf close by and keep chasing longer.
return Profile.extend("ai/kinds/battlenpc") {
    senses = { sound = { range = 12 } },
    behaviors = {
        Link  = { radius = 14, by = "family" },
        Leash = { radius = 60 },
    },
    rules = {
        { tier = 1, use = 27110, on = "target", when = "self:tp() >= 1000" },   -- pummel stands in for a bite
    },
}
