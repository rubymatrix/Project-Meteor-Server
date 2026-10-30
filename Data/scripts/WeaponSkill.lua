-- todo: add enums for status effects in Global.lua
--require("Global")
require("BattleUtils")
--[[
Weapon skill damage, healing and Stoneskin helpers. All are placeholders: damage is a flat 100 and
healing isn't worked out yet. statId is a BattleTemp stat; modifier is a Modifier such as Mind.
Damage formula notes: Data/Docs/Scripts/WeaponSkill.md.
--]]


local function calculateDamage(caster, target, skill, action)
		return 100
end

local function handleHealingSkill(caster, target, skill, action, statId, modifierId, multiplier, baseAmount)
	potency = potency or 1.0
	healAmount = baseAmount

	-- todo: scale by Mind
	local mind = caster:GetMod(Modifier.Mind)
end

local function handleAttackSkill(caster, target, skill, action, statId, modifierId, multiplier, baseAmount)
	-- todo: actually handle this
	damage = baseAmount or math.random(1,10) * 10

	return damage
end

local function handleStoneskin(caster, target, skill, action, statId, modifierId, damage)
	--[[
    if target.statusEffects.HasStatusEffect(StatusEffect.Stoneskin) then
        -- todo: damage reduction
        return true;
    end;
    ]]
	return false
end