require("Modifiers")

--[[
Protect (223129, from 27351 CNJ6, 300 s). Magnitude = the caster's Enhancing Magic Potency
(Command/Magic/Protect.lua): DEF +1 per 4.5 potency. There is no magic defense stat, so Enhanced
Protect (tier 2) adds each elemental resistance +1 per 6.7 potency. Amounts come from the stored
magnitude so onLose removes what onGain gave.
--]]

local ENH_PER_DEF = 4.5
local ENH_PER_RES = 6.7

local function def(effect) return math.floor(effect:GetMagnitude() / ENH_PER_DEF) end
local function res(effect) return math.floor(effect:GetMagnitude() / ENH_PER_RES) end

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Defense, def(effect))
	if effect:GetTier() == 2 then
		for i = Modifier.FireResistance, Modifier.WaterResistance do
			owner:AddMod(i, res(effect))
		end
	end
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Defense, def(effect))
	if effect:GetTier() == 2 then
		for i = Modifier.FireResistance, Modifier.WaterResistance do
			owner:SubtractMod(i, res(effect))
		end
	end
end
