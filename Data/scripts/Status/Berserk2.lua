require("Modifiers")

--[[
Berserk: each hit adds 20 attack (24 with the trait) and takes 20 defense, up to ten stacks.
Taking damage clears the stacks. Whirlwind uses the same per-hit numbers.
--]]

function onGain(owner, effect, actionContainer)
end

function onHit(effect, attacker, defender, skill, action, actionContainer)

	if effect:GetExtra() < 10 then
		effect:SetExtra(effect:GetExtra() + 1)

		local apPerHit = 20
		local defPerHit = 20

		if effect:GetTier() == 2 then
			apPerHit = 24
		end

		attacker:AddMod(Modifier.Attack, apPerHit)
		attacker:SubtractMod(Modifier.Defense, defPerHit)
	end
end

function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
	local apPerHit = 20
	local defPerHit = 20

	if effect:GetTier() == 2 then
		apPerHit = 24
	end

	defender:SubtractMod(Modifier.Attack, effect:GetExtra() * apPerHit)
	defender:AddMod(Modifier.Defense, effect:GetExtra() * defPerHit)
	effect:SetExtra(0)
end

function onLose(owner, effect, actionContainer)
	local apPerHit = 20
	local defPerHit = 20

	if effect:GetTier() == 2 then
		apPerHit = 24
	end

	owner:SubtractMod(Modifier.Attack, effect:GetExtra() * apPerHit)
	owner:AddMod(Modifier.Defense, effect:GetExtra() * defPerHit)
end