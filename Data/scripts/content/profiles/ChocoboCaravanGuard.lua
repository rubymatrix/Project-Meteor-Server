--[[
A caravan pack chocobo (client class ChocoboCaravanGuard). Walks the route with the caravan,
never fights, bolts when hurt and drops a pack; players coax it back by talking to it or
healing it.
--]]
return Profile.define {
    tags = { "caravan", "protected" },
    behaviors = {
        Follow = false,
        Assist = false,
        Combat = false,
        Avoid = false,
        Flee = { at = 30, distance = 18, recover = "coaxed", need = 2, coaxOnHeal = true },
    },
    onFled = function(self)
        local packs = self.bb.packs or 0
        if packs > 0 then
            self.bb.packs = packs - 1
            local enc = self:encounter()
            if enc then enc:counter("packsLost", 1) end
        end
    end,
    onTalked = function(self, ev)
        self:coax(ev.other, 1)
    end,
    onItemGiven = function(self, ev)
        self:coax(ev.other, 2)
    end,
}
