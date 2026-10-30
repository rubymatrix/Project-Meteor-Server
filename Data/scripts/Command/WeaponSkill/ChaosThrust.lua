require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Sixfold attack with a critical damage bonus; comboed from Impulse Drive it gains crit rate. Potency
1.8 for 3000 TP, x1.2 for the 80 s recast, split over six hits.
--]]

local params = {
	potency = 1.8 * 1.2 / 6,
	comboCrit = 15,
	critDamage = 0.2,
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
