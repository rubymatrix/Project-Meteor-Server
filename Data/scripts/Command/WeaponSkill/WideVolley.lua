require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits the target and enemies near it at low accuracy (DB -20, -5 hit-rate points); comboed from
Leaden Arrow, accuracyModifier 40 makes it +10 net. Potency 1.35 for 2000 TP, x0.8 as an area
attack.
--]]

local params = {
	potency = 1.35 * 0.8,
	status = "none",
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	skill.accuracyModifier = 40
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
