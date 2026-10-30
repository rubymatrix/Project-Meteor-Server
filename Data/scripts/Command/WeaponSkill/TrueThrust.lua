require("Global")
require("Battle/Actions")

--[[
Lancer opener, combo into Leg Sweep or Heavy Thrust, with +10 hit-rate points from the front.
--]]

local params = {
	potency = 1.0,
	positionalAcc = 10,
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
