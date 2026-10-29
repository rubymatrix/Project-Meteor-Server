-- A battle npc that belongs to another character (its owner) and takes its orders.
return Profile.define {
    behaviors = {
        Follow  = { leader = "owner", gap = 2 },
        Assist  = { leader = "owner" },
        Command = {},
        Combat  = {},
    },
    onSpawned = function(self)
        local owner = self:owner()
        if owner then self:setFaction(owner:faction()) end
    end,
}
