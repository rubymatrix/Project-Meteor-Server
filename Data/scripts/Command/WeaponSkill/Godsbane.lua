require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Threefold attack; comboed from Maim it gains crit rate. With Berserk up it clears the stacks (attack
and defense restored, the status stays) for +12.5 hit-rate points. C# runs onSkillFinish once per
hit, so the reset runs once in onSkillStart. Potency 1.8 over three hits.
--]]

local BERSERK = 223207     -- player Berserk; 223160 is the monster TP move

local params = {
	potency = 1.8 / 3,
	comboCrit = 15,
	status = "none",
}

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	local berserk = caster.statusEffects:GetStatusEffectById(BERSERK)
	if berserk ~= nil then
		local stacks = berserk:GetExtra()
		local apPerHit = (berserk:GetTier() == 2) and 24 or 20
		caster:SubtractMod(Modifier.Attack, apPerHit * stacks)
		caster:AddMod(Modifier.Defense, 20 * stacks)
		berserk:SetExtra(0)
		skill.accuracyModifier = 50
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.physicalWeaponskill(caster, target, skill, action, actionContainer, params)
end
