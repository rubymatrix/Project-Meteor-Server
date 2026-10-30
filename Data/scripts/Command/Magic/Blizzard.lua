require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Ice damage that adds Heavy for 30 s. Heavy lands on enfeebling potency, not magic accuracy.
--]]

local params = {
	magnitude = 800,
	stats = { [Modifier.Intelligence] = 0.5 },
	status = "always",
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
