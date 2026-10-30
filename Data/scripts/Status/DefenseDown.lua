require("Modifiers")
require("Battle/Formulas")

--[[

Defense Down

Lowers DEF by the command's statusMagnitude as a percentage of the owner's effective DEF when
it lands, or 20% when unset. The amount is kept in extra so onLose restores exactly what was taken.

--]]

local DEFAULT_PCT = 20

function onGain(owner, effect, actionContainer)
	local pct = effect:GetMagnitude()
	if pct == nil or pct <= 0 or pct > 100 then pct = DEFAULT_PCT end
	local amount = math.floor(formulas.effectiveDefense(owner) * pct / 100)
	effect:SetExtra(amount)
	owner:SubtractMod(Modifier.Defense, amount)
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.Defense, effect:GetExtra())
end
