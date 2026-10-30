require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Wind damage plus a bleed. The bleed lands on enfeebling potency, not magic accuracy. Its tick
scales with caster level up to 15 at Lv50, floor 2 (Lv7 2, Lv20 6, Lv35 10).
--]]

local params = {
	magnitude = 800,
	stats = { [Modifier.Intelligence] = 0.25, [Modifier.Mind] = 0.25 },
	status = "always",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	skill.statusMagnitude = math.max(2, math.floor(15 * caster:GetLevel() / 50))
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
