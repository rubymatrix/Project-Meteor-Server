return Profile.extend("ai/kinds/battlenpc") {
    faction = "Amaljaa",
    behaviors = { Link = { radius = 15, by = "family" } },
    rules = {
        { tier = 1, use = 27310, on = "target", when = "self:mpp() > 20", cooldown = 8 },   -- fire
    },
}
