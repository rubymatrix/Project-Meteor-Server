require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Usable only after a miss. High accuracy (DB 50, +12.5 hit-rate points), and a landed hit grants 1000
TP. Potency 0.9 as a 250 TP skill.
--]]

local params = {
	potency = 0.9,
	status = "none",
	after = function(caster, target, skill, action, container)
		if action:ActionLanded() then caster:AddTP(1000); end
	end,
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
