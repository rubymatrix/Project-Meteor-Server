require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Comboed from Fast Blade it generates x5.5 enmity (x4.5 on top of the hit's own). Mind also raises it
in retail, by an unknown amount, which is not modelled. Potency 1.1 for its 1500 TP cost.
--]]

local params = {
	potency = 1.1,
	comboEnmityMult = 5.5,
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
