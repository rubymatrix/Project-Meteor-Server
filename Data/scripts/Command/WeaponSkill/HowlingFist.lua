require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
More accurate from the flank (+12.5 hit-rate points); comboed from Demolish it deals x1.25 damage.
Potency 1.8 for its 3000 TP cost.
--]]

local params = {
	potency = 1.8,
	positionalAcc = 12.5,
	comboPotency = 1.25,
	status = "none",
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
