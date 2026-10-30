require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster; comboed from Impulse Drive it gains crit rate. Potency 1.35 for 2000
TP, x0.8 as an area attack.
--]]

local params = {
	potency = 1.35 * 0.8,
	comboCrit = 15,
	status = "none",
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
