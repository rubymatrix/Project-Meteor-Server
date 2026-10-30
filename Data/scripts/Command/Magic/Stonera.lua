require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Area earth damage that adds Heavy. Comboed from Stone it hits a single target for x1.5 damage.
--]]

local params = {
	magnitude = 950,
	stats = { [Modifier.Intelligence] = 0.5, [Modifier.Mind] = 0.5 },
	status = "always",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onCombo(caster, target, spell)
	spell.aoeType = 0
	spell.basePotency = spell.basePotency * 1.5
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
