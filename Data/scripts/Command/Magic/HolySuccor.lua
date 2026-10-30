require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Heals the target. Cast on someone else, the caster also heals 50% of the HP restored.
--]]

local params = {
	magnitude = 1500,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	params.mult = 1.0
	--8071401: Gallant Gauntlets: Enhances Holy Succor
	if caster:IsPlayer() and caster:HasItemEquippedInSlot(8071401, 13) then
		params.mult = 1.10
	end

	local restored = actions.healSpell(caster, target, skill, action, actionContainer, params)

	if caster.Id ~= target.Id and restored > 0 then
		local selfHeal = math.floor(restored / 2)
		caster:AddHP(selfHeal)
		--33012: You recover [amount] HP.
		actionContainer:AddHPAbsorbAction(caster.Id, 33012, selfHeal)
	end
end
