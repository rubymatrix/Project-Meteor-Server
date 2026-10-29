-- Bats are blind: sound only, all round.
return Profile.extend("ai/kinds/battlenpc") {
    senses = { sight = false, sound = { range = 10 } },
    rules = {
        { tier = 1, use = 23462, on = "target", when = "self:tp() >= 1000" },   -- dissent of the bat
    },
}
