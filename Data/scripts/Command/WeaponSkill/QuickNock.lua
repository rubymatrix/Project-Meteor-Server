require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
A short cone of five arrows. Comboed from Heavy Shot it fires all five at one target instead, at 0.5
potency each: 2.5 in all, which the 180 s recast pays for. Potency 1.0 for 1000 TP, x0.8 as a cone.
--]]

local params = {
	potency = 1.0 * 0.8,
	status = "none",
	scale = function(caster, target, skill, combo)
		if combo then return 0.5 / 0.8 end
		return 1.0
	end,
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	skill.numHits = 5
	skill.aoeType = 0
	skill.aoeTarget = 2
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
