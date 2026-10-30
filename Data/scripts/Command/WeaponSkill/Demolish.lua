require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Comboed from Pounce, a landed hit dispels one dispellable status (flag 8) from the target. Potency
1.1 for its 1500 TP cost.
--]]

local params = {
	potency = 1.1,
	status = "none",
	after = function(caster, target, skill, action, container, combo)
		if combo and action:ActionLanded() then
			local eff = target.statusEffects:GetRandomEffectByFlag(8);
			if eff ~= nil then target.statusEffects:RemoveStatusEffect(eff, container, 30336); end
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
