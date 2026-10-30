require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Wind damage around the target that dispels one effect on each target it lands on. Comboed from
Aero it hits a single target and removes 10 resist-rate points.
--]]

local params = {
	magnitude = 1200,
	stats = { [Modifier.Intelligence] = 0.5, [Modifier.Mind] = 0.5 },
	status = "none",
	comboAcc = 10,
	after = function(caster, target, skill, action, container, combo)
		-- 8 is LoseOnDispel.
		local eff = target.statusEffects:GetRandomEffectByFlag(8)
		if eff ~= nil and action:ActionLanded() then
			target.statusEffects:RemoveStatusEffect(eff, container, 30336)
		end
	end,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onCombo(caster, target, spell)
	spell.aoeType = 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
