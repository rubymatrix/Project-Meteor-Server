require("Global")
require("Battle/Actions")

--[[
Usable only right after evading; always stuns. Potency 0.97 matches retail hits against Pummel.
--]]

local params = {
	potency = 0.97,
	status = "always",
	statusChance = 1.0,
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
