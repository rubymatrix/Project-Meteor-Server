require("Global")
require("Battle/Actions")

--[[
Inflicts Bind; comboed from Piercing Arrow it lasts longer. Potency 0.85 as a 250 TP skill.
--]]

local params = {
	potency = 0.85,
	status = "always",
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
