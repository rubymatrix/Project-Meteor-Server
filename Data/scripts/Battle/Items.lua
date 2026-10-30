require("Global")
require("Modifiers")
require("Battle/Stats")
require("Battle/Formulas")
require("Battle/Ko")

--[[
Consumables with scripted effects (server_items_consumable type 'script'). C# ItemState calls
validate, which returns 0 or a worldMaster text id to refuse with, then use; C# consumes the item
and starts the recast. Enfeebling potions target an enemy, Company-issue raise items a KO'd ally.
--]]

items = items or {}

local M = Modifier
local F = formulas

local TEXT_CANNOT_USE = 32544          -- "You cannot use an item now." (int1 = 21007)
local TEXT_INVALID_TARGET = 32550      -- "Unable to execute command. Invalid target."
local TEXT_STATUS_GAIN = 30335         -- enfeeble gain line
local TEXT_BUFF_GAIN = 30328

local BLIND, SILENCE, PARALYSIS, POISON, SLEEP = 223007, 223006, 223005, 223011, 228001
local PROTECT, SHELL, LUNAR_CURTAIN = 223129, 223130, 223273

-- Enfeebling potions land at a flat 75%, the enfeeble landing cap, ignoring the user's magic
-- accuracy. Crowd-control diminishing returns still apply (StatusEffectContainer).
items.ENFEEBLE_CHANCE = 0.75
items.ENFEEBLE_RANGE = 15
items.ENFEEBLE = {
	[3020301] = { { BLIND, 10 } },                        -- Blinding Potion
	[3020302] = { { SILENCE, 10 } },                      -- Silencing Potion
	[3020303] = { { SLEEP, 10 } },                        -- Sleeping Potion
	[3020304] = { { PARALYSIS, 10 } },                    -- Paralyzing Potion
	[3020306] = { { POISON, 20 } },                       -- Poisoning Potion
	[3020307] = { { SILENCE, 10 }, { POISON, 10 } },      -- Smothering Potion
	[3020308] = { { PARALYSIS, 10 }, { POISON, 10 } },    -- Disabling Potion
}
-- Per 3 s tick: CNJ Poison's fixed 14 at Lv50, scaled by user level.
function items.poisonTick(level)
	return math.max(3, math.floor(14 * level / 50))
end

-- Success chance. They go through the normal Raise offer, so the KO'd player accepts and gets
-- Weakness on revive.
items.RAISE = {
	[3020412] = 1.0,    -- Company-issue Tonic
	[3020411] = 0.5,    -- Company-issue Expectorant
}

-- Protect / Shell for 5:00, sized from the user's own Enhancement Magic Potency like the spells
-- (Status/Protect.lua). Shell raises the elemental resistances, this server's magic defense.
-- Protect and Shell overwrite each other.
items.UNGUENT = {
	[3020501] = PROTECT,   -- Ironhide Unguent
	[3020502] = SHELL,     -- Ironwill Unguent
}

-- Lunar Curtain nullifies magic damage taken for 15 s: attack spells and elemental TP moves
-- through actions.attackSpell.
items.LUNAR_CURTAIN = 3020538

-- Maddening Potion: one-time enmity (190 at Lv50, level-scaled) on every enemy that hates the
-- user, not split between them. A medicine row, handled in items.onMedicine.
items.MADDENING_POTION = 3020305
items.MADDENING_ENMITY = 190


local function isEnemy(user, target)
	if target == nil or target == user then return false end
	local ok, mon = pcall(function() return target:IsMonster() end)
	return ok and mon and target:IsAlive()
end

local function inRange(user, target, yalms)
	local dx, dz = user.positionX - target.positionX, user.positionZ - target.positionZ
	return math.sqrt(dx * dx + dz * dz) <= yalms
end

function items.validate(user, target, itemId)
	if items.ENFEEBLE[itemId] ~= nil then
		if not isEnemy(user, target) then return TEXT_INVALID_TARGET end
		if not inRange(user, target, items.ENFEEBLE_RANGE) then return TEXT_INVALID_TARGET end
		return 0
	end
	if items.RAISE[itemId] ~= nil then
		if target == nil or target == user then return TEXT_INVALID_TARGET end
		local ok, dead = pcall(function() return target:IsDead() end)
		if not ok or not dead then return TEXT_INVALID_TARGET end
		return 0
	end
	if items.UNGUENT[itemId] ~= nil or itemId == items.LUNAR_CURTAIN then
		return user:IsAlive() and 0 or TEXT_CANNOT_USE
	end
	return TEXT_CANNOT_USE
end

-- Returns true if the status landed.
local function addStatus(owner, source, id, magnitude, duration, results, text)
	local se = GetWorldManager():GetStatusEffect(id)
	if se == nil then return false end
	se:SetMagnitude(magnitude)
	se:SetDuration(duration)
	se:SetOwner(owner)
	return owner.statusEffects:AddStatusEffect(se, source, results, text)
end

function items.use(user, target, itemId, results)
	local enf = items.ENFEEBLE[itemId]
	if enf ~= nil then
		for _, e in ipairs(enf) do
			if math.random() < items.ENFEEBLE_CHANCE then
				local mag = (e[1] == POISON) and items.poisonTick(user:GetLevel()) or 0
				addStatus(target, user, e[1], mag, e[2], results, TEXT_STATUS_GAIN)
			end
		end
		-- Using a potion on a monster is a hostile act: it hates the user (base hate only).
		pcall(function() target.hateContainer:AddBaseHate(user) end)
		return 0
	end

	local raise = items.RAISE[itemId]
	if raise ~= nil then
		if math.random() < raise then
			pcall(function() target:OfferRaise(user, ko.RAISE_HP_PERCENT, true) end)
		end
		return 0
	end

	local unguent = items.UNGUENT[itemId]
	if unguent ~= nil then
		local other = (unguent == PROTECT) and SHELL or PROTECT
		user.statusEffects:RemoveStatusEffect(other, results)
		addStatus(user, user, unguent, user:GetMod(M.EnhancementMagicPotency), 300, results, TEXT_BUFF_GAIN)
		return 0
	end

	if itemId == items.LUNAR_CURTAIN then
		addStatus(user, user, LUNAR_CURTAIN, 0, 15, results, TEXT_BUFF_GAIN)
		return 0
	end
	return TEXT_CANNOT_USE
end

-- Medicine rows (type 'medicine') with a one-time effect besides their status. C# calls this after
-- applying the row; unknown ids do nothing.
function items.onMedicine(user, itemId, results)
	if itemId == items.MADDENING_POTION then
		local amount = F.fixedEnmity(items.MADDENING_ENMITY, user:GetLevel())
		local ok, list = pcall(function() return user.CurrentArea:GetActorsAroundActor(user, 50) end)
		if not ok or list == nil then return end
		for a in list do
			pcall(function()
				if a:IsMonster() and a:IsAlive() and a.hateContainer:HasHateForTarget(user) then
					a.hateContainer:UpdateHate(user, amount)
				end
			end)
		end
	end
end

-- Lunar Curtain check for damage paths (actions.attackSpell).
function items.blocksMagic(target)
	local ok, has = pcall(function() return target.statusEffects:HasStatusEffect(LUNAR_CURTAIN) end)
	return ok and has
end

return items
