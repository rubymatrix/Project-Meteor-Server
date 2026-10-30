require("Global")
require("Battle/Actions")

--[[
Combo into Impulse Drive; from behind it gains crit rate. Potency 1.1 for its 1500 TP cost.
--]]

local params = {
	potency = 1.1,
	positionalCrit = 15,
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
