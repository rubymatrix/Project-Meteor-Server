--[[
Raiders that strike a caravan: they only see and only hit the pack chocobos.
--]]
return Profile.define {
	faction = "Monster",
	senses = { sight = { range = 30, cone = 360 }, filter = { tag = "caravan" }, levelGap = false },
	hate = { mode = "locked", tags = { "caravan" } },
	behaviors = {
		Roam = false,
		Link = { radius = 20, by = "group" },
		Leash = { radius = 0 },
		Detect = {},
	},
}
