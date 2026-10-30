require("Modifiers")
require("Battle/Statlayers")

--[[
KO penalties. Raise and Return give Weakness (max HP/MP -25%, 3 min); a revive while Weak or in
Brink of Death gives Brink of Death (max HP/MP and battle stats -50%, 3 min), and Brink only
restarts its timer. Enhanced Raise blocks both. The statuses keep running while KO'd.
--]]

ko = ko or {}

local M = Modifier

ko.WEAKNESS = 223165
ko.BRINK_OF_DEATH = 223197
ko.ENHANCED_RAISE = 27363       -- CNJ48 trait

ko.PENALTY_SECONDS = 180        -- both statuses
ko.WEAKNESS_PCT = 0.25          -- max HP/MP
ko.BRINK_PCT = 0.50             -- max HP/MP and battle stats

-- Full HP after the max is cut, so a Weak player comes back at 75% of normal. MP stays as at KO.
ko.RAISE_HP_PERCENT = 100
ko.RETURN_HP_PERCENT = 100

-- Attack, magic potency, defense and magic defense; this server's magic defense is the
-- elemental resistances.
ko.BRINK_STATS = {
	M.Attack, M.Defense,
	M.AttackMagicPotency, M.HealingMagicPotency, M.EnhancementMagicPotency, M.EnfeeblingMagicPotency,
}
for id = M.FireResistance, M.WaterResistance do
	ko.BRINK_STATS[#ko.BRINK_STATS + 1] = id
end

local function statusLoaded(id)
	local ok, se = pcall(function() return GetWorldManager():GetStatusEffect(id) end)
	return ok and se ~= nil
end

local function has(chara, id)
	return chara.statusEffects:GetStatusEffectById(id) ~= nil
end

-- Layers are sized from the base stats, so max HP/MP never drift from stacked deltas.
local function setPenalty(owner, layer, mod, pct)
	statlayers.set(owner, layer, mod, -pct)
end

-- Inside onCalculateBaseStats (fromStats) C# copies Hp/Mp into hpMax/mpMax itself, so no sync.
function ko.applyWeakness(owner, on, fromStats)
	local pct = on and ko.WEAKNESS_PCT or 0
	setPenalty(owner, "status:weakness", M.Hp, pct)
	setPenalty(owner, "status:weakness", M.Mp, pct)
	if not fromStats then statlayers.syncPools(owner) end
end

function ko.applyBrink(owner, on, fromStats)
	local pct = on and ko.BRINK_PCT or 0
	setPenalty(owner, "status:brink", M.Hp, pct)
	setPenalty(owner, "status:brink", M.Mp, pct)
	for _, mod in ipairs(ko.BRINK_STATS) do
		setPenalty(owner, "status:brink", mod, pct)
	end
	if not fromStats then statlayers.syncPools(owner) end
end

statlayers.register(ko.WEAKNESS, ko.applyWeakness)
statlayers.register(ko.BRINK_OF_DEATH, ko.applyBrink)

-- Call after Revive. penalty is false when Enhanced Raise stopped it. Returns the status id
-- applied, or 0.
function ko.applyRevivePenalty(player, kind, penalty)
	if penalty == false then
		return 0
	end

	local id = ko.WEAKNESS
	if has(player, ko.WEAKNESS) or has(player, ko.BRINK_OF_DEATH) then
		id = ko.BRINK_OF_DEATH
	end

	-- Rows are cached at startup; without them AddStatusEffect would build a nameless effect.
	if not statusLoaded(id) then
		print(string.format("[ko] status %d not loaded (server_statuseffects); no KO penalty", id))
		return 0
	end

	if id == ko.BRINK_OF_DEATH then
		player.statusEffects:RemoveStatusEffect(ko.WEAKNESS)
	end
	-- overwrite=Always restarts a running Brink.
	player.statusEffects:AddStatusEffect(id, 1, 0, ko.PENALTY_SECONDS, 0)
	return id
end

return ko
