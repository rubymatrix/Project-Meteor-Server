require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster, usable only after a block. Adds about 380 flat enmity at Lv50,
scaled by level, on top of the damage. Potency 0.9 as a 500 TP skill, x0.8 as an area attack.
--]]

local params = {
	potency = 0.9 * 0.8,
	enmityFlat = 380,
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
