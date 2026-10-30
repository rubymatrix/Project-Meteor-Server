--[[
Battle npcs on the players' side. Who they follow comes from the blackboard (bb.leader) or
their owner; content sets it. They stay with their leader instead of roaming or leashing home.
--]]
return Profile.extend("ai/kinds/battlenpc") {
    faction = "PlayerAlly",
    senses = { sight = false, sound = false },
    behaviors = {
        Roam   = false,
        Leash  = false,
        Follow = { leader = "leader", gap = 3, slot = "rear", warp = 40 },
        Assist = { leader = "leader" },
        Combat = {},
        Avoid  = { reaction = 0.8 },
    },
}
