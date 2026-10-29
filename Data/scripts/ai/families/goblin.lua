-- Goblins wander far and only fight back.
return Profile.extend("ai/kinds/battlenpc") {
    faction = "Goblin",
    behaviors = {
        Roam   = { radius = 30, delay = { 10, 25 } },
        Detect = false,
        Link   = { radius = 8, by = "family" },
    },
}
