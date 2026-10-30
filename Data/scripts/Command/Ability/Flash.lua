require("Global")
require("Ability")
require("Battle/Formulas")
require("Battle/Actions")

--[[
Adds about 380 enmity at Lv50, scaled by level, to each enemy hit; it is not split between them.
Sentinel and Antagonize raise it through actions.enmityScale.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27161: Enhanced Flash: Adds Blind effect to flash
	if caster:HasTrait(27161) then
		ability.statusChance = 1
	end

	--27162: Enhanced Flash II: Expands Flash to affect enemies near target
	if caster:HasTrait(27162) then
		ability.aoeTarget = TargetFindAOEType.Circle
	end

	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action.enmity = math.floor(formulas.fixedEnmity(380, caster:GetLevel()) * actions.enmityScale(caster))

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end