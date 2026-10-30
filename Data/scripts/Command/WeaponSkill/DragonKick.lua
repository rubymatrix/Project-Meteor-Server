require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Twofold attack. Comboed from Sucker Punch, the first hit may Pacify (base chance 0.5, rolled through
enfeebling potency). Potency 1.35 for 2000 TP, x1.1 for the 1.22a damage raise, split over two hits.
--]]

local params = {
	potency = 1.35 * 1.1 / 2,
	status = "none",
	after = function(caster, target, skill, action, container, combo)
		if combo and action.hitNum == 1 and action:ActionLanded() then
			local listed = 0.5;
			skill.statusChance = formulas.statusLandChance(caster, target, skill.statusId, listed, "rider");
			action:TryStatus(caster, target, skill, container, true);
		end
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
