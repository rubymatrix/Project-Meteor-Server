require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Hits enemies around the caster. Comboed from Path of the Storm with Berserk up, it clears the
Berserk stacks (attack and defense restored) for x1.5 damage. Potency 1.8 for 3000 TP, x0.8 as an
area attack.
--]]

local params = {
	potency = 1.8 * 0.8,
	status = "none",
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onCombo(caster, target, skill)
	local berserk = caster.statusEffects:GetStatusEffectById(223207)
	if berserk ~= nil then
		local apPerHit = (berserk:GetTier() == 2) and 24 or 20
		caster:SubtractMod(Modifier.Attack, apPerHit * berserk:GetExtra())
		caster:AddMod(Modifier.Defense, 20 * berserk:GetExtra())
		berserk:SetExtra(0)
		skill.basePotency = skill.basePotency * 1.5
	end
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
