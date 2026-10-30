require("Global")
require("Battle/Actions")

--[[
Usable only right after a block; combo into Spirits Within. Potency 0.87 matches retail hits against
Fast Blade.
--]]

local params = {
	potency = 0.87,
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
