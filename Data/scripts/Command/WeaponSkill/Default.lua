require("Global")
require("Battle/Actions")

--[[
Fallback for weaponskills without their own script: every monster TP move and any player weaponskill
not yet written. Physical moves use the player weaponskill formula with the monster's level weapon;
magic moves use the spell formula. skill.basePotency (100 = neutral) scales both.
--]]

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	if tostring(skill.actionType) == "Magic" then
		actions.attackSpell(caster, target, skill, action, actionContainer, {})
	elseif tostring(skill.actionType) == "Status" then
		action:DoAction(caster, target, skill, actionContainer)
	else
		actions.physicalWeaponskill(caster, target, skill, action, actionContainer, {})
	end
end
