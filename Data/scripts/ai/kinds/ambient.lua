-- Background life: wanders, never fights.
return Profile.define {
    faction = "Neutral",
    behaviors = {
        Idle = { emotes = {}, interval = { 20, 40 } },
        Roam = { radius = 8, delay = { 8, 20 } },
    },
}
