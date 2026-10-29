-- Battle npcs on the players' side. Who they follow comes from the blackboard (bb.leader) or
-- their owner; content sets it.
return Profile.define {
    faction = "PlayerAlly",
    senses = { sight = false, sound = false },
    behaviors = {
        Follow = { leader = "leader", gap = 3, slot = "rear", warp = 40 },
        Assist = { leader = "leader" },
        Combat = {},
        Avoid  = { reaction = 0.8 },
    },
}
