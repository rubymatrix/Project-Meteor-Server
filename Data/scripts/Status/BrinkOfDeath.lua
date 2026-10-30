require("Modifiers")
require("Battle/Ko")

--[[
Raised while still Weak: max HP, max MP and battle stats -50% for 180 s.
Battle/Ko.lua BRINK_STATS lists which modifiers count as battle stats.
--]]

function onGain(owner, effect, actionContainer)
	ko.applyBrink(owner, true)
end

function onLose(owner, effect, actionContainer)
	ko.applyBrink(owner, false)
end
