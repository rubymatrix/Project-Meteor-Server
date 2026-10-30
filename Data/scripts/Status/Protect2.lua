require("Modifiers")

--[[
Protect 2 (223239): the Protect cast applies 223129 whether traited or not. Kept as an alias of
Status/Protect.lua at tier 2 (Enhanced Protect resistances) for anything that still applies it.
--]]

local ENH_PER_DEF = 4.5
local ENH_PER_RES = 6.7

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Defense, math.floor(effect:GetMagnitude() / ENH_PER_DEF))
	for i = Modifier.FireResistance, Modifier.WaterResistance do
		owner:AddMod(i, math.floor(effect:GetMagnitude() / ENH_PER_RES))
	end
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Defense, math.floor(effect:GetMagnitude() / ENH_PER_DEF))
	for i = Modifier.FireResistance, Modifier.WaterResistance do
		owner:SubtractMod(i, math.floor(effect:GetMagnitude() / ENH_PER_RES))
	end
end
