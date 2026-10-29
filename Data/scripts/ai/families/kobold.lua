return Profile.extend("ai/kinds/battlenpc") {
    faction = "Kobold",
    behaviors = { Link = { radius = 15, by = "family" } },
    rules = {
        { tier = 1, use = 27190, on = "target", when = "self:tp() >= 1000" },   -- heavy swing
    },
}
