require("Global")
require("Ability")
require("Battle/Actions")

--[[
A jumping attack keyed to the weapon's base Damage: the auto-attack formula at potency 1.0, plus a
flat 1.2 x reference weapon Damage (102 at Lv50). Advances Power Surge.
Not done: the physical evasion while airborne.
--]]

local params = {
	kind = "aa",
	potency = 1.0,
	flatDamage = function(caster, target, skill)
		return 1.2 * stats.referenceWeaponDamage(caster:GetLevel())
	end,
	status = "none",
}

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	-- Drachen Breeches cut Jump's recast by 6 seconds.
	if caster:IsPlayer() and caster:HasItemEquippedInSlot(8051404, 12) then
		ability.recastTimeMs = ability.recastTimeMs - 6000
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
