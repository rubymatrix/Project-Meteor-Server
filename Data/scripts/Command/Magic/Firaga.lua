require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Fire damage around the target. Comboed from Fira it casts in half the time.
--]]

local params = {
	magnitude = 1600,
	stats = { [Modifier.Intelligence] = 1.5 },
	status = "none",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onCombo(caster, target, spell)
	spell.castTimeMs = spell.castTimeMs / 2
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
