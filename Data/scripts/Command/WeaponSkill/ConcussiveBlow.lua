require("Global")
require("Battle/Actions")

--[[
Comboed from Pummel it deals more damage; from the flank it inflicts Blind. Combo potency 1.1
matches retail hits against Pummel.
--]]

local params = {
	potency = 1.0,
	comboPotency = 1.1,
	status = "positional",
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
