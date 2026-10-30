require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
From behind it may inflict a bleed (chance 0.9, tick 25); comboed from Savage Blade the tick is 38.
Potency 1.8 for 3000 TP, x1.1 for the 1.22a damage raise.
--]]

local params = {
	potency = 1.8 * 1.1,
	status = "positional",
	statusChance = 0.9,
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	skill.statusMagnitude = actions.comboed(skill) and 38 or 25
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
