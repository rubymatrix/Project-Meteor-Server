require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Inflicts a bleed. Uncomboed it applies the tick-only Status/Bloodletter2.lua; comboed from Gloom
Arrow it applies Status/Bloodletter.lua, which also bursts when it ends. Piety raises the land
chance. Potency 1.3: a 1500 TP skill with an 80 s recast.
--]]

local params = {
	potency = 1.3,
	status = "always",          -- DB chance 0.75
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	skill.statusId = 223127
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
