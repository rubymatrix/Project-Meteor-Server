require("Modifiers")

--[[
Swiftsong (223224, from 27226 BRD/ARC26, 180 s or until enmity): movement speed +20%, or +40%
under Battle Voice (tier 2).
--]]

local function mult(effect)
	return (effect:GetTier() == 2) and 1.4 or 1.2
end

function onGain(owner, effect, actionContainer)
	owner:MultiplyMod(Modifier.MovementSpeed, mult(effect))
end

function onLose(owner, effect, actionContainer)
	owner:DivideMod(Modifier.MovementSpeed, mult(effect))
end
