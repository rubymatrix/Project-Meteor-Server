require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
From behind it may inflict Heavy (chance 0.75, duration from the DB). Potency 1.1 for its 1500 TP
cost.
--]]

local params = {
	potency = 1.1,
	status = "positional",
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
