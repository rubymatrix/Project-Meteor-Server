require("Global")
require("Ability")
require("BattleUtils")
require("Battle/Formulas")

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)

	--27163: Enhanced Rampart:Expands rampart to affect party members
	if caster:HasTrait(27163) then
		ability.aoeType = TargetFindAOEType.Circle
	end

	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action.enmity = formulas.fixedEnmity(190, caster:GetLevel())  --per target hit

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end