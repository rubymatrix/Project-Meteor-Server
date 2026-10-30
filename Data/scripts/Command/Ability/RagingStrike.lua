require("Global")
require("Ability")

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27243: Enhanced Raging Strike: Increases effect of Raging Strike by 50%
	ability.statusTier = 1
	if caster:HasTrait(27243) then
		ability.statusTier = 2
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	--If caster has raging strike, remove it and send message, otherwise apply it.
	local buff = caster.statusEffects:GetStatusEffectById(223221)

	if buff ~= nil then
		--30329: Your Raging Strike removes your Raging Strike effect.
		caster.statusEffects:RemoveStatusEffect(buff, actionContainer, 30329)
	else
		--DoAction handles rates, buffs, dealing damage
		action:DoAction(caster, target, skill, actionContainer)
	end
end