require("Global")
require("Ability")
require("Battle/Actions")

--[[
Cuts the archer's enmity on every enemy that hates them by 840 at Lv50, scaled by level.
Each enemy loses the full amount; it is not split between them.
--]]

local ENMITY_LV50 = 840

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27245: Swift Chameleon
	if caster:HasTrait(27245) then
		ability.recastTimeMs = ability.recastTimeMs - 60000
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local drop = formulas.fixedEnmity(ENMITY_LV50, caster:GetLevel())
	for _, mob in ipairs(actions.hatingEnemies(caster)) do
		mob.hateContainer:UpdateHate(caster, -drop)
	end
	action:DoAction(caster, target, skill, actionContainer)
end
