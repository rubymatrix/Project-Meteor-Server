require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Lightning damage. Comboed from Thundara its crits gain +175 critical potency (+0.35 damage),
added past the 175% crit-damage cap.
--]]

local params = {
	magnitude = 2150,
	stats = { [Modifier.Intelligence] = 1.5 },
	status = "none",
	comboCritUncapped = 175 * formulas.CRIT_POTENCY_PER_POINT,
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
