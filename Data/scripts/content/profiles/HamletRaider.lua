-- Beastmen storming a hamlet: march their lane to the supply caches, prefer the caches over
-- anyone in the way, never give up the chase.
return Profile.extend("ai/kinds/battlenpc") {
    senses = { sight = { range = 18, cone = 200 }, levelGap = false },
    hate = { mode = "weighted", tags = { cache = 4 } },
    behaviors = {
        Roam = false,
        Leash = false,
        Link = { radius = 12, by = "group" },
        Detect = { ignoreNeutral = true },
    },
}
