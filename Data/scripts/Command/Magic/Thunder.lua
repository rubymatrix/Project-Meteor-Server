require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Lightning damage. Starts the Thundara combo.
--]]

local params = {
	magnitude = 1050,
	stats = { [Modifier.Intelligence] = 0.5 },
	status = "none",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
