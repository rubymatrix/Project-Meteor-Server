require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
A ranged attack. From behind it may inflict Defense Down (chance 0.75) at -20% defense. Potency 1.35
for 2000 TP, x1.1 for the 1.22a damage raise.
--]]

local params = {
	potency = 1.35 * 1.1,
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
	skill.statusMagnitude = 20     -- percent
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
