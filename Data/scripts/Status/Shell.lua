require("Modifiers")

--[[
Shell (223130). Players get it only from Ironwill Unguent; magnitude = the user's Enhancing Magic
Potency (Battle/Items.lua). There is no magic defense stat, so Shell raises each elemental
resistance +1 per 6.7 potency, the Enhanced Protect rate. Protect and Shell overwrite each other
where they are applied.
--]]

local ENH_PER_RES = 6.7

local function res(effect) return math.floor(effect:GetMagnitude() / ENH_PER_RES) end

function onGain(owner, effect, actionContainer)
	for i = Modifier.FireResistance, Modifier.WaterResistance do
		owner:AddMod(i, res(effect))
	end
end

function onLose(owner, effect, actionContainer)
	for i = Modifier.FireResistance, Modifier.WaterResistance do
		owner:SubtractMod(i, res(effect))
	end
end
