require("Global")
require("Battle/Actions")

--[[
Comboed from Fast Blade it deals x1.07 damage, matching retail hits against Fast Blade.
--]]

local params = {
	potency = 1.0,
	comboPotency = 1.07,
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
