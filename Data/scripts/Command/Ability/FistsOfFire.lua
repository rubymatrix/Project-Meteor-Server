require("Global")
require("Ability")

--[[
Stance: attack +20% (+25% with Enhanced Fists of Fire).
Using it again ends it, and starting it ends the other two Fists stances.
--]]
local SELF, OTHERS = 223209, { 223210, 223211 }

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27124: Enhanced Fists of Fire
	if caster:HasTrait(27124) then
		ability.statusTier = 2
	end
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
