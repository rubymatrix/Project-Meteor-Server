require("Global")
require("Battle/Actions")

--[[
Pugilist opener, combo into Concussive Blow or Aura Pulse, with more damage from the front. Potency
1.0 is the pugilist reference; the x1.2 front bonus is a guess.
--]]

local params = {
	potency = 1.0,
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
