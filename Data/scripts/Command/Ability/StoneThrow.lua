require("Global")
require("Ability")
require("Battle/Actions")

--[[
The throw the client sends in place of Throw, likely when no throwing weapon is equipped, so it needs
none. Its range comes from the command sheet, not a weapon. Potency 0.5 on the auto-attack formula.
--]]

local params = {
	potency = 0.5,
}

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.rangedShot(caster, target, skill, action, actionContainer, params)
end
