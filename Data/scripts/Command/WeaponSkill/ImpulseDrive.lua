require("Global")
require("Battle/Actions")

--[[
More damage from the flank; comboed from Vorpal Thrust it gains crit rate. Potency 1.1 for its 1500
TP cost.
--]]

local params = {
	potency = 1.1,
	positionalPotency = 1.2,
	comboCrit = 15,
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
