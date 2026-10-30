require("Global")
require("Ability")

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27240: Enhanced Hawks Eye
	--Tier 2 raises the accuracy gain by 50% (Status/HawksEye.lua).
	if caster:HasTrait(27240) then
		ability.statusTier = 2
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action:DoAction(caster, target, skill, actionContainer)
end