require("Global")
require("Modifiers")
require("Battle/Stats")
require("Battle/Actions")

--[[
Heals the user by a level curve. Pugilists add INT/2 and Enhanced Second Wind adds 25%.
Each use varies by up to 2.6% either way.
--]]

local AMOUNT_CURVE = { {1, 35}, {6, 55}, {10, 80}, {20, 155}, {26, 200}, {30, 241}, {50, 580} }

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local amount = stats.interp(AMOUNT_CURVE, caster:GetLevel())
	if stats.classOf(caster) == stats.CLASS.PGL then
		amount = amount + caster:GetMod(Modifier.Intelligence) / 2
	end
	--27120: Enhanced Second Wind
	if caster:IsPlayer() and caster:HasTrait(27120) then
		amount = amount * 1.25
	end
	amount = amount * (0.974 + math.random() * 0.052)
	actions.healAbility(caster, target, skill, action, actionContainer, amount)
end
