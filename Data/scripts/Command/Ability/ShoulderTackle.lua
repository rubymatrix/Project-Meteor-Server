require("Global")
require("Ability")
require("Battle/Actions")

--[[
A charging attack that generates no enmity. It stuns only a target with no enmity toward the
caster, checked before the hit since the hit itself puts the caster on the hate list.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local fresh = not actions.hatesCaster(target, caster)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, {
		potency = 1.0,
		enmityMult = 0,
		status = fresh and "always" or "none",
	})
end
