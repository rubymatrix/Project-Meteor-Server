require("Global")
require("Ability")
require("Battle/Formulas")

--[[
Adds about 550 enmity at Lv50, scaled by level. Attack Down lands only with Enhanced Provoke
(the DB statusChance is 0).
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27200: Enhanced Provoke: Adds Attack Down effect to Provoke.
	if caster:HasTrait(27200) then
		ability.statusChance = 1.0
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action.enmity = formulas.fixedEnmity(550, caster:GetLevel())
	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end