require("Global")
require("Ability")
require("Modifiers")
require("Battle/Actions")

--[[
A jumping fire attack on the target and enemies near it. Uses the spell formula at magnitude 1200,
with the stat ratio from Piety only: a lancer has no attack magic potency to speak of.
--]]

local params = {
	magnitude = 1200,
	stats = { [Modifier.Piety] = 1.5 },
	statsOnly = true,
	status = "none",
}

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
