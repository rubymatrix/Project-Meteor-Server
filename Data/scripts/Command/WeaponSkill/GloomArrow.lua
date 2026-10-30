require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Comboed from Piercing Arrow it may inflict Blind (chance 0.75). Potency 1.0 for its 1000 TP cost.
--]]

local params = {
	potency = 1.0,
	status = "combo",
	statusChance = 0.75,
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
