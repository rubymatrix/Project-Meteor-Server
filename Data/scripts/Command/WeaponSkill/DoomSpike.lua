require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Pierces a line of enemies toward the target; comboed from Leg Sweep it gains +12.5 hit-rate points.
Its TP cost is a fixed 3000, so nothing scales with TP. Potency 1.8, x0.8 as an area attack.
--]]

local params = {
	potency = 1.8 * 0.8,
	status = "none",
	accScale = function(caster, target, skill, combo) return combo and 12.5 or 0 end,
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
