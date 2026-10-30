require("Global")
require("Battle/Actions")

--[[
Usable only right after a parry; inflicts Pacification. Potency 0.75 matches retail hits against
Heavy Swing.
--]]

local params = {
	potency = 0.75,
	status = "always",
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
