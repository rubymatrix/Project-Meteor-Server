require("Global")
require("Battle/Actions")

--[[
Ifrit's Hellfire, also under the unused IDs 23368, 23408 and 23581: he reappears at the arena
centre, readies for 2 s, then burns the whole arena (circle 50). MAGNITUDE is 10% under the fit to
retail hits on Lv50 players.
--]]

local MAGNITUDE = 3200

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, { magnitude = MAGNITUDE })
end
