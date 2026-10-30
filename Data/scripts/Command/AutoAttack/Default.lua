require("Global")
require("Battle/Actions")

--[[
Auto-attack for players and monsters. AttackState calls this once per hit; the hit count is the
weapon's frequency, 2 for fists. Damage is keyed to weapon Damage, not DPS: about 1.6 x Damage
before level difference and DEF. TP gain is handled in C#.
--]]

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.autoAttack(caster, target, skill, action, actionContainer)
end
