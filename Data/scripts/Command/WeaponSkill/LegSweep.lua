require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster. Comboed from True Thrust it may Stun: a DB chance of 0 means the
script decides, so the combo sets 1.0 and rolls it through enfeebling potency. Potency 1.0 for 1000
TP, x0.8 as an area attack.
--]]

local params = {
	potency = 1.0 * 0.8,
	status = "combo",
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
