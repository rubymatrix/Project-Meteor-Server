require("Modifiers")

--[[
Shroud of Saints (223226, from ability 27341 CNJ38), 20 s. Halves the enmity the owner generates
while it is up; enmity already on hate lists is untouched. Restores 3% of max MP per 3 s tick
through the Refresh mod.
--]]

local ENMITY_MULT = 0.5
local MP_PER_TICK = 0.03

function onGain(owner, effect, actionContainer)
	local mp = math.max(1, math.floor(owner:GetMaxMP() * MP_PER_TICK))
	effect:SetMagnitude(mp)
	owner:AddMod(Modifier.Refresh, mp)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Refresh, effect:GetMagnitude())
end

-- The command script has set the enmity by now; BattleUtils adds it to the hate list afterwards,
-- scaled again by the enmity modifier for physical attacks.
function onPreAction(effect, caster, target, skill, action, actionContainer)
	if action.enmity > 0 then
		action.enmity = math.floor(action.enmity * ENMITY_MULT)
	end
end
