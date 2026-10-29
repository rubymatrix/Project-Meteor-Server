return Profile.extend("ai/kinds/battlenpc") {
    faction = "Ixal",
    behaviors = { Link = { radius = 15, by = "family" } },
    rules = {
        { tier = 1, use = 27228, on = "target", when = "self:tp() >= 1000" },   -- heavy shot
    },
}
