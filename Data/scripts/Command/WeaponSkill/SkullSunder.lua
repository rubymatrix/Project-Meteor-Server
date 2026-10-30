require("Global")
require("Battle/Actions")

--[[
Comboed from Heavy Swing it generates x2.75 enmity: the hit's own plus x1.75. Potency 1.05 matches
retail hits against Heavy Swing.
--]]

local params = {
	potency = 1.05,
	comboEnmityMult = 2.75,
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
