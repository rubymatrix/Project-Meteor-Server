require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits the target and enemies near it. Comboed from Quick Nock it may Stun, with chance and duration
from the DB. Potency 1.8 for 3000 TP, x0.8 as an area attack.
--]]

local params = {
	potency = 1.8 * 0.8,
	status = "combo",           -- DB chance 0.75
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
