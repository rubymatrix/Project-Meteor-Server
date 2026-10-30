require("Global")
require("Ability")

--[[
Life Surge: clears Power Surge and moves the Life Surge buff up one stage.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	--27282: Enhanced Life Surge: Increases Absorb HP effect of Life Surge by 20%
	ability.statusTier = 1
	if caster:HasTrait(27282) then
		ability.statusTier = 2
	end

	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	-- Power Surge I-III (223212-223214) end with no message when Life Surge removes them.
	caster.statusEffects:RemoveStatusEffect(223212)
	caster.statusEffects:RemoveStatusEffect(223213)
	caster.statusEffects:RemoveStatusEffect(223214)


	--Using this ability moves to the next LS buff
	local removeId = 0
	--223215: Life Surge I
	--223216: Life Surge II
	--223217: Life Surge III
	--The stage is the status id; statusTier only marks Enhanced Life Surge.
	if caster.statusEffects:HasStatusEffect(223215) then
		removeId = 223215
		skill.statusId = 223216
	elseif caster.statusEffects:HasStatusEffect(223216) then
		removeId = 223216
		skill.statusId = 223217
	elseif caster.statusEffects:HasStatusEffect(223217) then
		effect = caster.statusEffects:GetStatusEffectById(223217)
		effect:RefreshTime()
		skill.statusId = 223217
	end

	if not (removeId == 0) then
		caster.statusEffects:ReplaceEffect(caster.statusEffects:GetStatusEffectById(removeId), skill.statusId, skill.statusTier, skill.statusMagnitude, skill.statusDuration)
	end
	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end