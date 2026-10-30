require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Fivefold attack at low accuracy (DB -40, -10 hit-rate points); comboed from Riot Blade the penalty
is lifted. Potency 1.1 for 1500 TP, x1.2 for the 20 s recast, split over five hits.
--]]

local params = {
	potency = 1.1 * 1.2 / 5,
	status = "none",
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	skill.accuracyModifier = 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
