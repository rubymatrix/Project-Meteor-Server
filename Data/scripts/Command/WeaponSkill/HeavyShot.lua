require("Global")
require("Battle/Actions")

--[[
Archer opener, combo into Leaden Arrow, or into Quick Nock from 8 yalms or more. The combo's range
check is not enforced yet: it needs C# support.
--]]

local params = {
	potency = 1.0,
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
