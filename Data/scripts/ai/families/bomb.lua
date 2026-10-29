-- Bombs swell when hurt; below a quarter they stop, flash and burst.
return Profile.extend("ai/kinds/battlenpc") {
    onHp = {
        [25] = function(self)
            self:push("Hold", { channels = { "Move" } })
            self:animate(0x11000105)
        end,
    },
}
