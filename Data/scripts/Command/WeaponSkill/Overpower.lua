require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
A cone in front of the caster, usable only after a parry. Potency 0.85 as a 250 TP skill, x0.8 as an
area attack.
--]]

local params = {
	potency = 0.85 * 0.8,
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
