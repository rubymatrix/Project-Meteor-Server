require("Global")
require("Ability")

--[[
The server has no ammunition model (arrows are not consumed), so Refill only plays its action.
--]]

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	action.amount = 0
	action:DoAction(caster, target, skill, actionContainer)
end
