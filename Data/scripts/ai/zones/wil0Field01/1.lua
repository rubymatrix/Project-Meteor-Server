-- A placement override: the first wharf rat spawn in Central Thanalan walks a beat instead of
-- roaming, and calls the second rat when it fights.
return Profile.define {
    behaviors = {
        Roam = false,
        Patrol = { route = { points = { { 25.6, 200, -450 }, { 33.6, 200, -450 }, { 33.6, 200, -442 }, { 25.6, 200, -442 } } }, mode = "loop", wait = 2 },
        Link = { radius = 15, by = "family" },
    },
}
