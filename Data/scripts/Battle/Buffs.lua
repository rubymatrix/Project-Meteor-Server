require("Modifiers")
require("Battle/Statlayers")

--[[
Percentage buffs kept as stat layers: Fists of Fire (+20% Attack), Fists of Earth (+20% Defense),
+25% at tier 2 for both, and HP Boost (+25% max HP). A stat recalc re-sizes each layer from the
base stat instead of compounding it. Status scripts call the apply functions.
--]]

buffs = buffs or {}
local M = Modifier

buffs.FISTS_OF_FIRE, buffs.FISTS_OF_EARTH, buffs.HP_BOOST = 223209, 223210, 223029

-- onGain passes the status, which is not in the container yet.
local function tierPct(owner, id, effect)
	if effect == nil then
		local ok, eff = pcall(function() return owner.statusEffects:GetStatusEffectById(id) end)
		if ok then effect = eff end
	end
	if effect == nil then return 0.20 end
	return (effect:GetTier() == 2) and 0.25 or 0.20
end

function buffs.applyFistsOfFire(owner, on, fromStats, effect)
	statlayers.set(owner, "fists_of_fire", M.Attack, on and tierPct(owner, buffs.FISTS_OF_FIRE, effect) or 0)
end

function buffs.applyFistsOfEarth(owner, on, fromStats, effect)
	statlayers.set(owner, "fists_of_earth", M.Defense, on and tierPct(owner, buffs.FISTS_OF_EARTH, effect) or 0)
end

-- Inside onCalculateBaseStats (fromStats) C# copies Hp into hpMax itself, so no sync.
-- Gaining the boost also heals the added max HP.
function buffs.applyHpBoost(owner, on, fromStats)
	local before = owner:GetMaxHP()
	statlayers.set(owner, "hp_boost", M.Hp, on and 0.25 or 0)
	if fromStats then return end
	statlayers.syncPools(owner)
	local gained = owner:GetMaxHP() - before
	if on and gained > 0 then owner:AddHP(gained) end
end

statlayers.register(buffs.FISTS_OF_FIRE, buffs.applyFistsOfFire)
statlayers.register(buffs.FISTS_OF_EARTH, buffs.applyFistsOfEarth)
statlayers.register(buffs.HP_BOOST, buffs.applyHpBoost)

return buffs
