require("Global")
require("Ability")

--[[
Stance: weaponskill recast -20%. No trait enhances it.
Using it again ends it, and starting it ends the other two Fists stances.
--]]
local SELF, OTHERS = 223211, { 223209, 223210 }

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local current = caster.statusEffects:GetStatusEffectById(SELF)
	if current ~= nil then
		--30329: the same stance-off text Power Surge uses.
		caster.statusEffects:RemoveStatusEffect(current, actionContainer, 30329)
		return
	end
	for _, id in ipairs(OTHERS) do
		caster.statusEffects:RemoveStatusEffect(id, actionContainer, 30331)
	end
	action:DoAction(caster, target, skill, actionContainer)
end
