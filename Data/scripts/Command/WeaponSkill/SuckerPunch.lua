require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
A landed hit from the flank restores MP: 0.3 x damage, or 0.4 x damage + 180 comboed from Pounce.
Combo into Dragon Kick. Potency 1.0 for its 1000 TP cost.
--]]

local params = {
	potency = 1.0,
	status = "none",
	after = function(caster, target, skill, action, container, combo, posMet)
		if not (posMet and action:ActionLanded()) then return end
		local mp = combo and (0.40 * action.amount + 180) or (0.30 * action.amount);
		mp = math.floor(mp);
		caster:AddMP(mp);
		--30452: You recover x MP.
		container:AddMPAbsorbAction(caster.Id, 30452, mp);
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
