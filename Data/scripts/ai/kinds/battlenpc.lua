-- Every battle npc starts here. The pool's detection flags add senses on top of these.
return Profile.define {
    faction = "Monster",
    -- Pools with aggroType 0 (neutral) never aggro; Detect skips them.
    senses = { sight = { range = 15, cone = 120 }, levelGap = 10 },
    behaviors = {
        Idle   = {},
        Roam   = { radius = 15, delay = { 5, 15 }, pace = "walk" },
        Detect = {},
        Link   = { radius = 10, by = "family" },
        Combat = {},
        Leash  = { radius = 50, reset = true },
    },
}
