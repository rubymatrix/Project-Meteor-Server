require("Global")
require("Ability")
require("Battle/Actions")

--[[
The next spell has no cast or recast time (Status/PresenceOfMind.lua). Healer's Culottes (AF legs)
cut the recast by 30 s.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	if caster:IsPlayer() and caster:HasItemEquippedInSlot(8051406, 12) then
		ability.recastTimeMs = ability.recastTimeMs - 30000
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.statusAbility(caster, target, skill, action, actionContainer, {})
end
