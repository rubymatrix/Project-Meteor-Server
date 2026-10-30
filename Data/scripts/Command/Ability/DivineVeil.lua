require("Global")
require("Ability")

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	--8051401: Gallant Cuisses (legs, slot 12): Enhances Divine Veil.
	if caster:HasItemEquippedInSlot(8051401, 12) then
		skill.statusTier = 2
	end

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end