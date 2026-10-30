require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Heals a large portion of the target's HP. Uses the shared heal formula, so crits, Cleric Stance
and heal enmity apply.
--]]

local params = {
	magnitude = 2000,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.healSpell(caster, target, skill, action, actionContainer, params)
end
