require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster and stuns those attacking the caster; comboed from Skull Sunder it
gains crit rate. The Rampage reset is not modelled. Potency 1.0 for 1000 TP, x0.8 as an area attack.
--]]

local params = {
	potency = 1.0 * 0.8,
	comboCrit = 15,
	status = "targetingCaster",
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
