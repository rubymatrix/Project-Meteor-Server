require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Small heal through the shared heal formula in Battle/Formulas.lua.
--]]

local params = {
	magnitude = 1000,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.healSpell(caster, target, skill, action, actionContainer, params)
end
