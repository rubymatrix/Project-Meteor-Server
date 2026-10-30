require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster; comboed from Pummel it may inflict Slow. Potency 1.1 for its 1500 TP
cost, x0.8 as an area attack, x1.1 for the 1.22a damage raise.
--]]

local params = {
	potency = 1.1 * 0.8 * 1.1,
	status = "combo",
	statusChance = 0.5,
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
