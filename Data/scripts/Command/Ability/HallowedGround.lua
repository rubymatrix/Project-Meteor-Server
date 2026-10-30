require("Global")
require("Battle/Formulas")
require("Battle/Actions")

--[[
Makes the paladin immune to damage for 20 s; no attack pierces it here. Adds 1140 enmity at Lv50,
scaled by level and split across the enemies that already hate the paladin.
--]]

local ENMITY_LV50 = 1140

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.statusAbility(caster, target, skill, action, actionContainer)
	actions.spreadEnmity(caster, caster, formulas.fixedEnmity(ENMITY_LV50, caster:GetLevel()))
end
