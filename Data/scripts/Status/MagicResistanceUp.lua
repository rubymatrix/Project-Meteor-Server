require("Modifiers")

--[[
Magic Resistance Up (223047), meant for O-App-Pesi's ward in man2g0 Beckon of the Elementals.
The ward's Wind, Earth and Water choices all give this one status. It cuts attack-spell damage
taken by the magnitude as a percentage, 20% when unset (Battle/Formulas.lua spellDamage).
--]]

local DEFAULT_PCT = 20

function onGain(owner, effect, actionContainer)
	local pct = effect:GetMagnitude()
	if pct == nil or pct <= 0 or pct > 100 then pct = DEFAULT_PCT end
	pct = math.floor(pct)
	effect:SetExtra(pct)
	owner:AddMod(Modifier.MagicResistance, pct)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.MagicResistance, effect:GetExtra())
end
