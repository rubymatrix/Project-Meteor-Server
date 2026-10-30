--[[
Things that can be attacked but never act: supply caches, barricades, gates.
--]]
return Profile.define {
	tags = { "structure" },
	senses = { sight = false, sound = false, magic = false, lowHp = false },
	behaviors = {},
}
