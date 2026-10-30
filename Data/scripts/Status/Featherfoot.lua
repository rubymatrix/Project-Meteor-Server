require("Modifiers")

--[[
Evasion +15 until the first evade. That evade returns a flat 140 MP, not a share of the attack,
or 175 with Enhanced Featherfoot (tier 2, set by Command/Ability/Featherfoot.lua).
--]]

local MP_PER_EVADE = 140
local ENHANCED_MULT = 1.25

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.RawEvadeRate, 15)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.RawEvadeRate, 15)
end

function onEvade(effect, attacker, defender, skill, action, actionContainer)
	local mpToReturn = MP_PER_EVADE
	if effect:GetTier() == 2 then
		mpToReturn = math.floor(MP_PER_EVADE * ENHANCED_MULT)
	end

	defender:AddMP(mpToReturn)
	--33010: You recover x MP from Featherfoot
	actionContainer:AddMPAction(defender.Id, 33010, mpToReturn)
	--Featherfoot is lost after evading
	defender.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
end
