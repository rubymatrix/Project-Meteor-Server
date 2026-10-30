require("Global")
require("Battle/Actions")

--[[
Combo into Maim, with more damage from the flank. Potency 0.9 matches retail hits against Heavy
Swing.
--]]

local params = {
	potency = 0.9,
	positionalPotency = 1.2,
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
