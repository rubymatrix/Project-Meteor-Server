require("Global")
require("Ability")
require("Battle/Actions")

--[[
Adds a kick to auto-attacks for 20 s (Status/SpinningHeel.lua) and ends Hundred Fists, since the
two can't be up together. The auto-attack damage penalty has no known size and isn't applied.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	caster.statusEffects:RemoveStatusEffect(223244, actionContainer, 30331)
	actions.statusAbility(caster, target, skill, action, actionContainer, {})
end
