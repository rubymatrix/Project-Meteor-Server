require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Comboed from Brutal Swing it gains +12.5 hit-rate points. Potency 1.1 for its 1500 TP cost.
--]]

local params = {
	potency = 1.1,
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
