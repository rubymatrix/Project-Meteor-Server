require("Global")
require("Ability")

--[[
Gives every party member in range HP Boost (max HP +25%, 60 s), and the bard Battle Voice for 30 s.
Songs cast while Battle Voice is up are doubled: Command/Magic sets tier 2 or doubles the magnitude.
--]]

local BV_SECONDS = 30

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action:DoAction(caster, target, skill, actionContainer)

	if caster.Id == target.Id then
		local effect = GetWorldManager():GetStatusEffect(223253)
		if effect ~= nil then
			effect:SetDuration(BV_SECONDS)
			caster.statusEffects:AddStatusEffect(effect, caster, actionContainer)
		end
	end
end
