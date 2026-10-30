require("Modifiers")
require("BattleUtils")

function onGain(owner, effect, actionContainer)
	--Untraited Sentinel is 30% damage taken down, traited is 50%
	local amount = 30
	if effect:GetTier() == 2 then
		amount = 50
	end

	owner:AddMod(Modifier.DamageTakenDown, amount)
end

function onLose(owner, effect, actionContainer)
	local amount = 30
	if effect:GetTier() == 2 then
		amount = 50
	end

	owner:SubtractMod(Modifier.DamageTakenDown, amount)
end

--Enmity x1.2 on damage and Flash while active is applied by Battle/Actions.lua enmityScale.
function onHit(effect, attacker, defender, skill, action, actionContainer)
end
