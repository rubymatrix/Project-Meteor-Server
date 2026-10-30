--[[
Bats are blind: sound only, all round.
--]]
return Profile.define {
    senses = { sight = false, sound = { range = 10 } },
}
