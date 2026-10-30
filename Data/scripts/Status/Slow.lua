require("Modifiers")

--[[
Slow (223003). Magnitude = multiplier on the Delay modifier (auto-attack delay in ms). Aura Pulse
sets none, so the default is x1.65, the low end of the only measured slow (mob delay 65-80% longer).
--]]

local DEFAULT_SLOW_MULT = 1.65

local function slowMult(effect)
	local m = effect:GetMagnitude()
	if m == nil or m <= 1 then
		return DEFAULT_SLOW_MULT
	end
	return m
end

function onGain(owner, effect, actionContainer)
	owner:MultiplyMod(Modifier.Delay, slowMult(effect))
end

function onLose(owner, effect, actionContainer)
	owner:DivideMod(Modifier.Delay, slowMult(effect))
end
