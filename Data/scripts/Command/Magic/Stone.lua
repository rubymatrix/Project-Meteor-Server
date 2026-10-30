require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Earth damage that lowers Magic Evasion. Starts the Stonera combo. Damage is x1.1 so CNJ's only
steady nuke keeps pace with THM's Thunder at the same level, cast and recast.
--]]

local params = {
	magnitude = 950,
	stats = { [Modifier.Intelligence] = 0.25, [Modifier.Mind] = 0.25 },
	status = "always",
	scale = function() return 1.1 end,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	skill.statusMagnitude = 50
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
