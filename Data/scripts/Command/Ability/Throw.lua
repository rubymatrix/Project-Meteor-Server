require("Global")
require("Ability")
require("Battle/Actions")

--[[
Hurls the throwing weapon: the auto-attack formula at potency 1.0 on the throwing-weapon slot, which
the client uses for Throw instead of the main hand. Refused without a throwing weapon. TP comes from
the auto-attack path. The animation id is a placeholder until a client test confirms it.
--]]

local params = {
	potency = 1.0,
	slot = stats.SLOT_THROWINGWEAPON,
}

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	if caster:IsPlayer() and stats.weapon(caster, stats.SLOT_THROWINGWEAPON).missing then
		return 32553   -- "That command cannot be performed."
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.rangedShot(caster, target, skill, action, actionContainer, params)
end
