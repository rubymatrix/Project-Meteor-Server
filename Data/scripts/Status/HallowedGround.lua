require("Modifiers")

--[[
DamageTakenDown 100 zeroes physical and spell damage in Battle/Formulas.lua and BattleUtils, so
no attack pierces it. Needs status row 223249 (flags 9 = LoseOnDeath | LoseOnDispel).
--]]

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.DamageTakenDown, 100)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.DamageTakenDown, 100)
end