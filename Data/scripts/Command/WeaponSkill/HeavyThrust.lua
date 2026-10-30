require("Global")
require("Battle/Actions")

--[[
Stuns a target that is attacking the caster; comboed from True Thrust the stun lasts longer. Potency
1.1 for its 1500 TP cost.
--]]

local params = {
	potency = 1.1,
	status = "targetingCaster",
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
