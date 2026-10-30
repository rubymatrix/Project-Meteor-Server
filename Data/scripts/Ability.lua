-- todo: add enums for status effects in Global.lua
require("Global")
require("BattleUtils")

--[[
     statId - see BattleTemp.cs
     modifier - Modifier.Intelligence, Modifier.Mind (see Modifier.cs)
     multiplier - 
  ]]
function handleHealingSkill(caster, target, skill, action, statId, modifierId, multiplier, baseAmount)
	potency = potency or 1.0
	healAmount = baseAmount

	-- todo: shit based on mnd
	local mind = caster:GetMod(Modifier.Mind)
end

function handleAttackSkill(caster, target, skill, action, statId, modifierId, multiplier, baseAmount)
	-- todo: actually handle this
	damage = baseAmount or math.random(1,10) * 10

	return damage
end

function handleStoneskin(caster, target, skill, action, statId, modifierId, damage)
	--[[
    if target.statusEffects.HasStatusEffect(StatusEffect.Stoneskin) then
        -- todo: damage reduction
        return true;
    end;
    ]]
	return false
end

--For abilities that inflict statuses, like aegis boon or taunt
function onStatusAbilityFinish(caster, target, skill, action)
	--action.CalcHitType(caster, target, skill);
	action:DoAction(caster, target, skill)
	action:TryStatus(caster, target, skill, false)

	return action.amount
end

function onAttackAbilityFinish(caster, target, skill, action)
	local damage = math.random(50, 150)
	action.amount = damage
	action:DoAction(caster, target, skill)

	return action.amount
end

function onHealAbilityFinish(caster, target, skill, action)
	local amount = math.random(150, 250)
	action.amount = amount
	action:DoAction(caster, target, skill)
	action:TryStatus(caster, target, skill, true)
	return action.amount
end