require("Global")
require("Battle/Actions")

--[[
Applies Sacred Prism for 60 s; Status/SacredPrism.lua holds the cast-time and area rule. It adds
no enmity: the retail amount is small and varies.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27360: Swift Sacred Prism
	if caster:IsPlayer() and caster:HasTrait(27360) then
		ability.recastTimeMs = ability.recastTimeMs - 30000
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.statusAbility(caster, target, skill, action, actionContainer)
end
