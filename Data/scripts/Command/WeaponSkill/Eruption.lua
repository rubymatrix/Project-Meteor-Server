require("Global")
require("Battle/Actions")

--[[
Ifrit's Eruption: a dummy actor bursts fire in radius 7.5, 4 s after its mark. MAGNITUDE is fitted
to retail hits on Lv50 players (about 525 damage per 1000 magnitude from a Lv58 caster). Shape and
radius come from the encounter script and the mob skill seed.
--]]

local MAGNITUDE = 3500

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, { magnitude = MAGNITUDE })
end
