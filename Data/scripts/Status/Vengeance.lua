require("Modifiers")
require("BattleUtils")

--[[
Vengeance (223250, MRD 27186): halves the damage of attacks taken and counters each one that lands
for the halved amount + 1. The AF body (tier 2, set in Command/Ability/Vengeance.lua) extends both
to magic.
--]]

local function applies(effect, skill)
	if skill == nil then return false end
	local t = skill:GetActionType()
	return t == ActionType.Physical or (t == ActionType.Magic and effect:GetTier() == 2)
end

-- Halve the incoming hit before Stoneskin, crit, block and parry are applied, and remember the
-- halved amount for the counter.
function onPreAction(effect, caster, target, skill, action, actionContainer)
	if not applies(effect, skill) then
		effect:SetExtra(0)
		return
	end
	local halved = math.floor(action.amount / 2)
	action.amount = halved
	effect:SetExtra(halved)
end

function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
	local halved = effect:GetExtra()
	effect:SetExtra(0)
	if halved <= 0 or not applies(effect, skill) or not action:ActionLanded() then return end

	local amount = halved + 1
	attacker:DelHP(amount, actionContainer)
	--30379: "Counter! ..." on the defender's own row.
	actionContainer:AddAction(defender.Id, 30379, 0x48000200, amount, 1, 1)
end
