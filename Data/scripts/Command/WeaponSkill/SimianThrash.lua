require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Ninefold attack at a fixed 2000 TP; comboed from Concussive Blow it deals x1.3 damage. Potency 1.35
for 2000 TP, x1.3 for the 80 s recast, split over nine hits.
--]]

local params = {
	potency = 1.35 * 1.3 / 9,
	comboPotency = 1.3,
	status = "none",
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
