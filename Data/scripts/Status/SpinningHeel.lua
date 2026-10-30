require("Modifiers")

--[[
Spinning Heel (223245): adds a kick to auto-attacks, one hit on top of the weapon's own count
(Character.autoAttackBaseHits, set by Player.CalculateBaseStats). SetMod makes onLose land back on
the weapon count. Player.RebaseWeaponMods keeps the kick through a stat recalc.
--]]

local function baseHits(owner, kickApplied)
	local ok, n = pcall(function() return owner.autoAttackBaseHits end)
	if not ok or n == nil or n < 1 then
		n = owner:GetMod(Modifier.HitCount)
		if kickApplied then n = n - 1 end
	end
	if n == nil or n < 1 then n = 1 end
	return n
end

function onGain(owner, effect, actionContainer)
	owner:SetMod(Modifier.HitCount, baseHits(owner, false) + 1)
end

function onLose(owner, effect, actionContainer)
	owner:SetMod(Modifier.HitCount, baseHits(owner, true))
end
