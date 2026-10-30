require("Global")
require("Magic")
require("Modifiers")
require("Battle/Actions")

--[[
Fallback for spells without their own script, mostly monster spells (Fire II, Blizzard II and so
on). Attack spells go through actions.attackSpell at magnitude basePotency with INT x0.5, the THM
Fire weights. Other spells use DoAction and TryStatus.
--]]

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	if tostring(skill.actionType) == "Magic" then
		local bp = skill.basePotency
		if bp == nil or bp <= 0 then bp = 1000 end
		-- attackSpell multiplies magnitude by basePotency/100; divide it back out
		local params = {
			magnitude = bp / actions.basePotencyScale(skill),
			stats = { [Modifier.Intelligence] = 0.5 },
			status = "always",
		}
		actions.attackSpell(caster, target, skill, action, actionContainer, params)
		return
	end

	action.amount = skill.basePotency
	action:DoAction(caster, target, skill, actionContainer)
	action:TryStatus(caster, target, skill, actionContainer, true)
end
