require("Modifiers")
require("BattleUtils")

--[[

Excruciate

Spell crit rate grows 4 points per 3 s tick (8 traited). It is added after the crit-rate clamp in
formulas.critRate, since forcing crits is the point. It ends after the spell that crits, so every
target of an AoE spell gets the bonus; physical crits don't end it. Needs status row 223231
(flags 2107401) with tickMs 3000.

--]]

local RATE_PER_TICK = 4         -- crit-rate percentage points
local RATE_PER_TICK_TRAIT = 8

local function isSpell(skill)
	return skill ~= nil and skill:GetCommandType() == CommandType.Spell
end

function onGain(owner, effect, actionContainer)
	effect:SetMagnitude(0)
	effect:SetExtra(0)
end

function onTick(owner, effect, actionContainer)
	local rate = RATE_PER_TICK
	if effect:GetTier() == 2 then
		rate = RATE_PER_TICK_TRAIT
	end
	effect:SetMagnitude(effect:GetMagnitude() + rate)
end

function onPreAction(effect, caster, target, skill, action, actionContainer)
	if isSpell(skill) and action.critRate ~= nil then
		action.critRate = math.min(100, action.critRate + effect:GetMagnitude())
	end
end

--Mark only; removal waits for the end of the command so every AoE target gets the bonus.
function onCrit(effect, attacker, defender, skill, action, actionContainer)
	if isSpell(skill) then
		effect:SetExtra(1)
	end
end

function onCommandFinish(effect, owner, skill, actionContainer)
	if effect:GetExtra() == 1 then
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
