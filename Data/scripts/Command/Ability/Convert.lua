require("Global")
require("Ability")

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local newMp = math.min(caster:GetHP(), caster:GetMaxMP())
	local newHp = math.min(caster:GetMP(), caster:GetMaxHP())
	caster:SetHP(newHp)
	caster:SetMP(newMp)

	--Set effect id
	action:DoAction(caster, target, skill, actionContainer)
end