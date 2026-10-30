require("Global")
require("Battle/Actions")

--[[
Stuns from behind; combo into Demolish or Sucker Punch. Potency 1.0 is a guess.
--]]

local params = {
	potency = 1.0,
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
