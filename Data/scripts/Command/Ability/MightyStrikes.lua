require("Global")
require("Ability")
require("Battle/Actions")

--[[
For 15 s, every attack made with an axe is a critical hit (Status/MightyStrikes.lua).
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.statusAbility(caster, target, skill, action, actionContainer, {})
end
