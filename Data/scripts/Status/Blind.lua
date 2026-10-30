require("Modifiers")

--[[

Blind

Hit rate down by the command's statusMagnitude, or 20 points when it sets none. It lowers
RawHitRate because formulas.hitRate reads that for players and monsters alike; monster
Accuracy is not modelled.

--]]

local DEFAULT_POINTS = 20

local function points(effect)
	local m = effect:GetMagnitude()
	if m == nil or m <= 0 then m = DEFAULT_POINTS end
	return m
end

function onGain(owner, effect, actionContainer)
	effect:SetExtra(points(effect))
	owner:SubtractMod(Modifier.RawHitRate, effect:GetExtra())
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.RawHitRate, effect:GetExtra())
end
