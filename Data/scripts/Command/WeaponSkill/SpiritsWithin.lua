require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
High-accuracy attack (DB 50, +12.5 hit-rate points) that weakens as the caster loses HP: x(HP% + 25)
/ 125, 1.0 at full HP down to 0.2 at 0 HP. Comboed from Phalanx it generates x2.5 enmity. Potency
1.8 for its 3000 TP cost.
--]]

local params = {
	potency = 1.8,
	comboEnmityMult = 2.5,
	status = "none",
	scale = function(caster) return (caster:GetHPP() + 25) / 125 end,
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
