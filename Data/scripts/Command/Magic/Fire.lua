require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Fire damage around the target. Starts the Fira combo.
--]]

local params = {
	magnitude = 950,
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
