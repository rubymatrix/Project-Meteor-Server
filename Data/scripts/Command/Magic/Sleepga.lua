require("Global")
require("Magic")
require("Battle/Actions")

--[[
Puts the target and enemies near it to sleep for 60 s.
Landing is capped at 75% and depends only on magic accuracy (useMacc). StatusEffectContainer
applies the Sleep diminishing returns when it lands.
--]]

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.enfeebleSpell(caster, target, skill, action, actionContainer, { useMacc = true })
end
