require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Lightning damage with a 4 s Stun. Comboed from Thunder it drops the stun for x3.5 damage and half
the recast. The x1.6 scale fits retail damage for an uncomboed Thundara, which the client
magnitude alone undershoots.
--]]

local params = {
	magnitude = 500,
	stats = { [Modifier.Intelligence] = 1.0 },
	status = "notCombo",
	scale = function() return 1.6 end,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onCombo(caster, target, spell)
	spell.statusChance = 0
	spell.basePotency = spell.basePotency * 3.5
	spell.recastTimeMs = spell.recastTimeMs / 2
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
