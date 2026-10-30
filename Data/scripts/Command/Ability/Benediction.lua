require("Global")
require("Ability")
require("Battle/Actions")

--[[
Fully restores the HP of every party member in range. Heal enmity is 0.6 per HP restored, as
for a cure.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local missing = target:GetMaxHP() - target:GetHP()
	actions.healAbility(caster, target, skill, action, actionContainer, math.max(0, missing))
end
