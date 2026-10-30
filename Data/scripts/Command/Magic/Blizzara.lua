require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Area ice damage that can Bind for 30 s. The Bind chance is the DB statusChance.
--]]

local params = {
	magnitude = 550,
	stats = { [Modifier.Intelligence] = 0.25 },
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
