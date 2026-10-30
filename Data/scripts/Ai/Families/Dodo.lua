--[[
Dodos are skittish: they bolt when hurt and come back once healed.
--]]
return Profile.define {
	behaviors = {
		Flee = { at = 25, distance = 20, recover = "hp", recoverHp = 50 },
	},
}
