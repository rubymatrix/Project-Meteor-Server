require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
May inflict Paralysis, with chance and duration from the DB; comboed from Feint the duration
doubles. Potency 0.95 for its 750 TP cost.
--]]

local params = {
	potency = 0.95,
	status = "always",          -- DB chance 0.75
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	skill.statusDuration = skill.statusDuration * 2
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
