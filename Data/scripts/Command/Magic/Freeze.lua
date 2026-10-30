require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Ice damage that reduces enmity. Its damage makes no enmity, and it removes a flat 720 at Lv50,
scaled by caster level. The cut leaves at least 1 because UpdateHate adds as an unsigned int.
--]]

local ENMITY_REDUCTION = 720

local params = {
	magnitude = 1200,
	stats = { [Modifier.Intelligence] = 1.0 },
	enmityMult = 0,
	status = "none",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, params)

	local ok, hc = pcall(function() return target.hateContainer end)
	if ok and hc ~= nil and hc:HasHateForTarget(caster) then
		local current = hc:GetHateList()[caster].cumulativeEnmity
		local take = math.min(formulas.fixedEnmity(ENMITY_REDUCTION, caster:GetLevel()), current - 1)
		if take > 0 then
			hc:UpdateHate(caster, -take)
		end
	end
end
