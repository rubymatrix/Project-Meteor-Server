require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Lightning damage. Comboed from Thundara it hits harder the lower the caster's HP: x1 at full HP,
x2 at 0 HP.
--]]

local params = {
	magnitude = 2200,
	stats = { [Modifier.Intelligence] = 1.5 },
	status = "none",
	scale = function(caster, target, skill, combo)
		if not combo then return 1.0 end
		return 1 + (1 - caster:GetHPP() / 100)
	end,
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
