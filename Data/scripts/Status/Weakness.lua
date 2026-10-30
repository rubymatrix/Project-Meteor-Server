require("Modifiers")
require("Battle/Ko")

--[[
Weakness (223165): max HP and max MP -25% for 180 s after being raised or using Return. Raised
again while it is on -> Brink of Death (Battle/Ko.lua applyRevivePenalty). The penalty is a stat
layer, so refreshing can't stack it.
--]]

function onGain(owner, effect, actionContainer)
	ko.applyWeakness(owner, true)
end

function onLose(owner, effect, actionContainer)
	ko.applyWeakness(owner, false)
end
