--[[
Every battle npc starts here.
The pool adds Detect when aggressive (aggroType) and Link when it
links (linkType); the pool's detection flags add senses. Families add or tune either.
--]]
return Profile.define {
	faction = "Monster",
	senses = { sight = { range = 15, cone = 120 }, levelGap = 10 },
	behaviors = {
		Idle   = {},
		Roam   = { radius = 15, delay = { 5, 15 }, pace = "walk" },
		Combat = {},
		Leash  = { radius = 50, reset = true },
	},
	rules = {
		{ tier = 9, use = "moves", on = "target", when = "self:tp() >= 1000" },
	},
}
