require("Global")
require("Battle/Actions")

--[[
Usable only right after a miss; combo into Disembowel. High accuracy: the DB accuracyMod 100 gives
+25 hit-rate points. Potency 0.85 as a 250 TP skill.
--]]

local params = {
	potency = 0.85,
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
