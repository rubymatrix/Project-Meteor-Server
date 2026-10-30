require("Global")
require("Battle/Actions")

--[[
Combo into Gloom Arrow, or into Shadowbind from 8 yalms or more. Potency 1.0 for its 1000 TP cost.
--]]

local params = {
	potency = 1.0,
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
