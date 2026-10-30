require("Modifiers")

stats = stats or {}

stats.CLASS = { PGL = 2, GLA = 3, MRD = 4, ARC = 7, LNC = 8, THM = 22, CNJ = 23 }
stats.JOB_TO_CLASS = { [15] = 2, [16] = 3, [17] = 4, [18] = 7, [19] = 8, [26] = 22, [27] = 23 }

local M = Modifier

stats.MOB_HP_BASE = {
	{1, 67}, {5, 102}, {10, 175}, {16, 317}, {26, 603}, {32, 897}, {41, 1621.7}, {47, 2356},
	{67, 9101.1}, {76, 10693}, {78, 11703}, {88, 17918},
}
stats.MOB_HP_SCALE = 1.0

-- By server_battlenpc_genus.genusId. Unlisted families are 1.0.
stats.MOB_HP_FAMILY = {
	[11] = 1.2,    -- Mole (snapping shrew)
	[12] = 1.2,    -- Rodent (hare, marmot, squirrel, dormouse, glirulus)
	[14] = 1.2,    -- Funguar
	[15] = 1.2,    -- Flying-trap (roselets, toadtrap)
	[60] = 1.2,    -- Ogre
	[23] = 1.2,    -- Amalj'aa
	[42] = 1.2,    -- Dodo
	[3]  = 0.92,   -- Wolf
	[43] = 0.92,   -- Bat
	[35] = 0.92,   -- Diremite
	[26] = 0.92,   -- Goblin
	[1002] = 0.85, -- Firefly
}

stats.MOB_MP_BASE = {
	{1, 110}, {10, 200}, {20, 400}, {30, 800}, {40, 1500}, {50, 2800},
	{60, 4800}, {70, 8000}, {80, 13000}, {90, 18000},
}
stats.MOB_MP_CASTER_MULT = 5
stats.MOB_MP_MAX = 32767

local function interp(anchors, level)
	if level <= anchors[1][1] then return anchors[1][2] end
	for i = 2, #anchors do
		local a, b = anchors[i - 1], anchors[i]
		if level <= b[1] then
			return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1])
		end
	end
	-- Monsters go above 50.
	local a, b = anchors[#anchors - 1], anchors[#anchors]
	return b[2] + (b[2] - a[2]) * (level - b[1]) / (b[1] - a[1])
end
stats.interp = interp

-- Attributes before class multiplier and points. Monsters above 50 grow slower than the Lv40-50 slope.
stats.ATTR_CURVE = { {1, 21}, {8, 34}, {9, 36}, {20, 62}, {30, 98}, {40, 148}, {50, 226}, {90, 433} }

-- primary/secondary: where the automatic point split goes.
stats.CLASS_PROFILE = {
	[2]  = { str = 1.08, vit = 0.98, dex = 1.00, int = 1.06, mnd = 0.92, pie = 0.92, primary = M.Strength,     secondary = M.Intelligence, hp = 0.98, mp = 1.00 },
	[3]  = { str = 1.06, vit = 1.04, dex = 1.00, int = 0.90, mnd = 1.06, pie = 0.92, primary = M.Strength,     secondary = M.Mind,         hp = 1.00, mp = 1.60 },
	[4]  = { str = 1.08, vit = 1.08, dex = 0.98, int = 0.90, mnd = 0.90, pie = 0.90, primary = M.Strength,     secondary = M.Vitality,     hp = 1.03, mp = 1.00 },
	[7]  = { str = 1.00, vit = 0.95, dex = 1.08, int = 0.92, mnd = 0.95, pie = 1.08, primary = M.Piety,        secondary = M.Dexterity,    hp = 0.92, mp = 1.20 },
	[8]  = { str = 1.08, vit = 0.98, dex = 1.02, int = 0.90, mnd = 0.92, pie = 1.06, primary = M.Strength,     secondary = M.Piety,        hp = 0.97, mp = 1.00 },
	[22] = { str = 0.90, vit = 0.92, dex = 0.95, int = 1.10, mnd = 1.00, pie = 1.06, primary = M.Intelligence, secondary = M.Piety,        hp = 0.82, mp = 1.60 },
	[23] = { str = 0.90, vit = 0.95, dex = 0.95, int = 1.00, mnd = 1.10, pie = 1.06, primary = M.Mind,         secondary = M.Piety,        hp = 0.85, mp = 1.60 },
}
local DEFAULT_PROFILE = { str = 1, vit = 1, dex = 1, int = 1, mnd = 1, pie = 1, primary = M.Strength, secondary = M.Vitality, hp = 1, mp = 1 }

-- HP = HP_CURVE * class hp + VIT.
stats.HP_CURVE = { {1, 100}, {10, 250}, {20, 470}, {27, 655}, {31, 850}, {40, 1400}, {50, 2100} }

-- MP = MP_CURVE * class mp + PIE.
stats.MP_CURVE = { {1, 30}, {10, 70}, {20, 130}, {26, 172}, {30, 230}, {40, 700}, {50, 1650} }

-- What a naked character shows.
stats.ATK_BASE_CURVE = { {1, 53}, {8, 74}, {9, 77}, {20, 115}, {30, 170}, {40, 250}, {50, 340} }
stats.MAGIC_BASE_PER_LEVEL = 4.8
-- Typical gear DEF at a level: best armour per slot on the item sheet, which climbs steeply after
-- Lv30; a Lv50 tank carries about 1000.
stats.GEAR_DEF_CURVE = { {1, 30}, {10, 65}, {20, 130}, {30, 275}, {40, 490}, {50, 1000} }

function stats.bonusPoints(level)
	if level < 10 then return 0 end
	return 5 + (level - 10)
end

function stats.bonusPointCap(level)
	if level < 10 then return 0 end
	return 3 + math.floor((level - 9) / 2)
end

-- For a typical character (no player): half to primary, half to secondary, the rest to VIT first.
function stats.bonusAllocation(classId, level)
	local p = stats.profile(classId)
	local bp, cap = stats.bonusPoints(level), stats.bonusPointCap(level)
	local out = { [M.Strength] = 0, [M.Vitality] = 0, [M.Dexterity] = 0,
				  [M.Intelligence] = 0, [M.Mind] = 0, [M.Piety] = 0 }
	out[p.primary] = math.min(cap, math.ceil(bp / 2))
	out[p.secondary] = math.min(cap, bp - out[p.primary])
	local left = bp - out[p.primary] - out[p.secondary]
	for _, id in ipairs({ M.Vitality, M.Strength, M.Dexterity, M.Mind, M.Piety, M.Intelligence }) do
		if left <= 0 then break end
		local add = math.min(cap - out[id], left)
		if add > 0 then out[id] = out[id] + add left = left - add end
	end
	return out
end

local MIDLANDER  = { 16, 15, 14, 16, 13, 16,  16, 13, 15, 15, 15, 16 }
local WILDWOOD   = { 14, 13, 18, 17, 12, 16,  12, 14, 18, 17, 14, 15 }
local DUSKWIGHT  = { 15, 14, 15, 18, 15, 13,  14, 16, 12, 17, 15, 16 }
local PLAINSFOLK = { 13, 13, 17, 16, 15, 16,  14, 13, 15, 16, 17, 15 }
local DUNESFOLK  = { 12, 12, 15, 16, 17, 18,  17, 12, 16, 18, 15, 12 }
stats.TRIBE = {
	[1] = MIDLANDER, [2] = MIDLANDER,
	[3] = { 18, 17, 15, 13, 15, 12,  15, 16, 14, 14, 18, 13 },   -- Highlander
	[4] = WILDWOOD, [5] = WILDWOOD,
	[6] = DUSKWIGHT, [7] = DUSKWIGHT,
	[8] = PLAINSFOLK, [9] = PLAINSFOLK,
	[10] = DUNESFOLK, [11] = DUNESFOLK,
	[12] = { 16, 15, 17, 13, 14, 15,  18, 15, 13, 15, 12, 17 },  -- Seeker of the Sun
	[13] = { 13, 12, 16, 14, 18, 17,  13, 18, 15, 14, 16, 14 },  -- Keeper of the Moon
	[14] = { 17, 18, 13, 12, 16, 14,  13, 17, 17, 12, 13, 18 },  -- Sea Wolf
	[15] = { 15, 16, 12, 15, 17, 15,  18, 14, 16, 13, 14, 15 },  -- Hellsguard
}
stats.TRIBE_MEAN = 15
local TRIBE_RESISTS = { M.FireResistance, M.IceResistance, M.WindResistance, M.EarthResistance, M.LightningResistance, M.WaterResistance }

function stats.tribeOf(player)
	local tribe = nil
	pcall(function() tribe = player.playerWork.tribe end)
	return tribe and stats.TRIBE[tribe] or nil
end

function stats.classOf(chara)
	local c = chara:GetClass()
	return stats.JOB_TO_CLASS[c] or c
end

function stats.profile(classId)
	return stats.CLASS_PROFILE[classId] or DEFAULT_PROFILE
end

local BONUS_ORDER = { M.Strength, M.Vitality, M.Dexterity, M.Intelligence, M.Mind, M.Piety }
-- A player who hasn't allotted points for this class gets the automatic split, the same one
-- stats.expected uses, so damage and hit rate don't drop until they choose.
function stats.bonusFor(classId, level, player)
	if player ~= nil and player:HasBonusAllotment(classId) then
		local points = {}
		for i, id in ipairs(BONUS_ORDER) do points[id] = player:GetBonusPoint(classId, i - 1) end
		return points
	end
	return stats.bonusAllocation(classId, level)
end

function stats.baseAttributes(classId, level, player)
	local p = stats.profile(classId)
	local a = interp(stats.ATTR_CURVE, level)
	local out = {
		[M.Strength]     = a * p.str,
		[M.Vitality]     = a * p.vit,
		[M.Dexterity]    = a * p.dex,
		[M.Intelligence] = a * p.int,
		[M.Mind]         = a * p.mnd,
		[M.Piety]        = a * p.pie,
	}
	for id, pts in pairs(stats.bonusFor(classId, level, player)) do out[id] = out[id] + (pts or 0) end
	local tribe = player ~= nil and stats.tribeOf(player) or nil
	if tribe ~= nil then
		for i, id in ipairs(BONUS_ORDER) do out[id] = out[id] + tribe[i] - stats.TRIBE_MEAN end
	end
	for k, v in pairs(out) do out[k] = math.floor(v + 0.5) end
	return out
end

function stats.baseHp(classId, level, vit)
	return math.floor(interp(stats.HP_CURVE, level) * stats.profile(classId).hp + vit)
end

function stats.baseMp(classId, level, pie)
	return math.floor(interp(stats.MP_CURVE, level) * stats.profile(classId).mp + pie)
end

function stats.expected(classId, level)
	local attrs = stats.baseAttributes(classId, level)
	local e = {
		str = attrs[M.Strength], vit = attrs[M.Vitality], dex = attrs[M.Dexterity],
		int = attrs[M.Intelligence], mnd = attrs[M.Mind], pie = attrs[M.Piety],
	}
	e.atk = interp(stats.ATK_BASE_CURVE, level) + e.str * 2 / 3
	e.gearDef = interp(stats.GEAR_DEF_CURVE, level)
	e.def = e.gearDef + 0.67 * e.vit
	e.magic = stats.MAGIC_BASE_PER_LEVEL * level
	return e
end

-- Typical Damage of a 3.0 s weapon at a level, fit to the item sheet.
function stats.referenceWeaponDamage(level)
	local l = math.max(level, 1) - 1
	return 7 + 1.0 * l + 0.012 * l * l
end

-- Equipment

-- The client's calculateLevelAdjust: penalty for gear above the user's level.
stats.LEVEL_ADJUST = {
	high = { 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1 },     -- item level >= 31
	mid  = { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3 },     -- 11-30
	low  = { 0.9, 0.85, 0.8, 0.75, 0.7, 0.6, 0.5 },   -- <= 10
}
function stats.levelAdjust(userLevel, itemLevel)
	if itemLevel == nil or itemLevel <= userLevel then return 1.0 end
	local d = math.min(7, itemLevel - userLevel)
	if itemLevel >= 31 then return stats.LEVEL_ADJUST.high[d] end
	if itemLevel >= 11 then return stats.LEVEL_ADJUST.mid[d] end
	return stats.LEVEL_ADJUST.low[d]
end

function stats.itemFactor(chara, slot, d)
	local broken = false
	pcall(function() broken = chara:IsEquippedGearBroken(slot) end)
	if broken then return 0 end
	local lvl = 0
	pcall(function() lvl = d.level end)
	return stats.levelAdjust(chara:GetLevel(), lvl) * stats.compatibility(chara, d)
end

function stats.compatibility(chara, d)
	local c = 1.0
	pcall(function() c = d:GetCompatibility(chara:GetClass()) end)
	return c
end

-- paramBonusType 15001 + n is modifier n. 16xxx rows are flags with value 0.
function stats.gearTotals(chara)
	local t = { def = 0, eva = 0, atk = 0, acc = 0, matk = 0, macc = 0, crit = 0, parry = 0, mods = {} }
	if not chara:IsPlayer() then return t end
	local ok, eq = pcall(function() return chara:GetEquipment() end)
	if not ok or eq == nil then return t end
	for slot = 0, 22 do
		local item = eq:GetItemAtSlot(slot)
		if item ~= nil then
			local d = GetItemGamedata(item.itemId)
			local f = d ~= nil and stats.itemFactor(chara, slot, d) or 0
			if d ~= nil and f > 0 then
				pcall(function() t.def = t.def + f * d.defense t.eva = t.eva + f * d.evasion end)
				pcall(function()
					t.atk = t.atk + f * d.attack t.acc = t.acc + f * d.rate
					t.matk = t.matk + f * d.magicAttack t.macc = t.macc + f * d.magicRate
					t.crit = t.crit + f * d.critical t.parry = t.parry + f * d.parry
				end)
				pcall(function()
					for i = 1, 10 do
						local ty = d["paramBonusType" .. i]
						local v = d["paramBonusValue" .. i]
						if ty ~= nil and ty >= 15001 and ty <= 15105 and v ~= 0 then
							local id = ty - 15001
							t.mods[id] = (t.mods[id] or 0) + f * v
						end
					end
				end)
				pcall(function() stats.addMateria(chara, item, f, t.mods) end)
			end
		end
	end
	return t
end

stats.MATERIA_SLOTS = 5
function stats.materiaItemId(materiaType, grade)
	return 10100001 + 4 * (materiaType - 1) + math.floor(grade / 4)
end
function stats.addMateria(chara, item, f, mods)
	local m = item.modifiers
	if m == nil then return end
	for slot = 0, stats.MATERIA_SLOTS - 1 do
		local ty = m:GetMateriaType(slot)
		local md = ty > 0 and GetMateriaGamedata(ty) or nil
		if md ~= nil then
			local grade = m:GetMateriaGrade(slot)
			local itemData = GetItemGamedata(stats.materiaItemId(ty, grade))
			if itemData == nil or chara:GetLevel() >= itemData.level then
				for b = 1, 2 do
					local bonusType = b == 1 and md.bonus1Type or md.bonus2Type
					local v = md:GetBonusValue(b, grade)
					if bonusType >= 15001 and bonusType <= 15105 and v ~= 0 then
						local id = bonusType - 15001
						mods[id] = (mods[id] or 0) + f * v
					end
				end
			end
		end
	end
end

-- Player.SLOT_*
stats.SLOT_MAINHAND = 0
stats.SLOT_THROWINGWEAPON = 4

function stats.weapon(chara, slot)
	slot = slot or stats.SLOT_MAINHAND
	local w = { damage = 0, delay = 3.0, hits = 1, dps = 0, ammo = 0 }
	if chara:IsPlayer() then
		local found = false
		pcall(function()
			local item = chara:GetEquipment():GetItemAtSlot(slot)
			if item ~= nil then
				local d = GetItemGamedata(item.itemId)
				local f = stats.itemFactor(chara, slot, d)
				w.damage = d.damagePower * f
				w.delay = d.damageInterval
				w.hits = math.max(1, d.frequency)
				found = f > 0
				pcall(function() w.ammo = math.max(0, d.ammoVirtualDamagePower or 0) * f end)
			end
		end)
		if slot ~= stats.SLOT_MAINHAND then
			w.missing = not found or w.damage <= 0
			w.dps = (w.damage + w.ammo) / math.max(w.delay, 0.5)
			return w
		end
		if w.damage <= 0 then w.damage = math.max(1, math.floor(stats.referenceWeaponDamage(chara:GetLevel()) * 0.5)) end
	else
		local mult = chara:GetMod(132)
		if mult == nil or mult <= 0 then mult = 1 end
		w.damage = (7 + 1.0 * chara:GetLevel()) * mult
		local delay = chara:GetMod(M.Delay)
		w.delay = (delay ~= nil and delay > 0) and delay / 1000 or 4.2
	end
	w.dps = (w.damage + w.ammo) / w.delay
	return w
end

-- Players

local function setBase(chara, id, value)
	value = math.floor(value + 0.5)
	local ok = pcall(function() chara:SetBaseStat(id, value) end)
	if not ok then chara:SetMod(id, value) end
end

function stats.applyPlayerBaseStats(player)
	local classId = stats.classOf(player)
	local level = player:GetLevel()
	local attrs = stats.baseAttributes(classId, level, player)
	local gear = stats.gearTotals(player)

	for id, v in pairs(attrs) do setBase(player, id, v + (gear.mods[id] or 0)) end
	local vit = attrs[M.Vitality] + (gear.mods[M.Vitality] or 0)
	local pie = attrs[M.Piety] + (gear.mods[M.Piety] or 0)
	local str = attrs[M.Strength] + (gear.mods[M.Strength] or 0)
	local dex = attrs[M.Dexterity] + (gear.mods[M.Dexterity] or 0)
	local int = attrs[M.Intelligence] + (gear.mods[M.Intelligence] or 0)
	local mnd = attrs[M.Mind] + (gear.mods[M.Mind] or 0)

	local hp = stats.baseHp(classId, level, vit) + (gear.mods[M.Hp] or 0)
	local mp = stats.baseMp(classId, level, pie) + (gear.mods[M.Mp] or 0)
	setBase(player, M.Hp, hp)
	setBase(player, M.Mp, mp)

	-- The attack curve already holds the naked STR, so only points and gear add to it.
	local addedStr = (stats.bonusFor(classId, level, player)[M.Strength] or 0) + (gear.mods[M.Strength] or 0)
	local magicBase = stats.MAGIC_BASE_PER_LEVEL * level
	local derived = {
		[M.Attack]                  = interp(stats.ATK_BASE_CURVE, level) + addedStr * 2 / 3 + gear.atk + (gear.mods[M.Attack] or 0),
		[M.Accuracy]                = interp(stats.ATK_BASE_CURVE, level) + gear.acc + (gear.mods[M.Accuracy] or 0),
		[M.Defense]                 = gear.def + (gear.mods[M.Defense] or 0),
		[M.Evasion]                 = interp(stats.ATK_BASE_CURVE, level) + gear.eva + (gear.mods[M.Evasion] or 0),
		[M.AttackMagicPotency]      = magicBase + int / 4 + gear.matk + (gear.mods[M.AttackMagicPotency] or 0),
		[M.HealingMagicPotency]     = magicBase + mnd / 4 + (gear.mods[M.HealingMagicPotency] or 0),
		[M.EnhancementMagicPotency] = magicBase + vit / 4 + (gear.mods[M.EnhancementMagicPotency] or 0),
		[M.EnfeeblingMagicPotency]  = magicBase + pie / 4 + (gear.mods[M.EnfeeblingMagicPotency] or 0),
		[M.MagicAccuracy]           = magicBase + mnd / 4 + gear.macc + (gear.mods[M.MagicAccuracy] or 0),
		[M.MagicEvasion]            = magicBase + pie / 4 + (gear.mods[M.MagicEvasion] or 0),
		[M.CriticalHitRating]       = gear.crit + (gear.mods[M.CriticalHitRating] or 0),
		[M.Parry]                   = gear.parry + (gear.mods[M.Parry] or 0),
	}
	for id, v in pairs(derived) do setBase(player, id, v) end

	local tribe = stats.tribeOf(player)
	for i, id in ipairs(TRIBE_RESISTS) do
		setBase(player, id, (tribe and tribe[6 + i] or 0) + (gear.mods[id] or 0))
	end

	-- Bonus on top of the base regen. Gear only.
	setBase(player, M.RestingHp, gear.mods[M.RestingHp] or 0)
	setBase(player, M.RestingMp, gear.mods[M.RestingMp] or 0)

	return { class = classId, level = level, hp = hp, mp = mp, attrs = attrs, gear = gear }
end

-- Monsters

-- Geometric between {level, value} anchors.
local function interpGeo(anchors, level)
	if level <= anchors[1][1] then return anchors[1][2] end
	for i = 2, #anchors do
		local a, b = anchors[i - 1], anchors[i]
		if level <= b[1] then
			return a[2] * (b[2] / a[2]) ^ ((level - a[1]) / (b[1] - a[1]))
		end
	end
	local a, b = anchors[#anchors - 1], anchors[#anchors]
	return b[2] * (b[2] / a[2]) ^ ((level - b[1]) / (b[1] - a[1]))
end
stats.interpGeo = interpGeo

function stats.mobFamilyHpMult(genusId)
	return stats.MOB_HP_FAMILY[genusId or 0] or 1.0
end

function stats.mobHp(level, mult)
	-- The nudge keeps float error from flooring an exact anchor to one less.
	return math.floor(interpGeo(stats.MOB_HP_BASE, level) * (mult or 1) * stats.MOB_HP_SCALE + 1e-6)
end

function stats.mobIsCaster(mob)
	local c = mob:GetClass()
	return c == 22 or c == 23 or c == 26 or c == 27
end

function stats.mobMp(level, caster)
	local mp = interp(stats.MOB_MP_BASE, level)
	if caster then mp = mp * stats.MOB_MP_CASTER_MULT end
	return math.min(stats.MOB_MP_MAX, math.floor(mp))
end

function stats.mobExpected(level)
	return stats.expected(0, level)
end

function stats.applyMobBaseStats(mob)
	local level = mob:GetLevel()
	if level == nil or level <= 0 then return 0 end
	local hp = mob:GetMod(M.Hp)
	if hp == nil or hp <= 0 then
		local genus = 0
		pcall(function() genus = mob.genusId or 0 end)
		hp = stats.mobHp(level, stats.mobFamilyHpMult(genus))
		mob:SetMod(M.Hp, hp)
	end
	local a = math.floor(interp(stats.ATTR_CURVE, level) + 0.5)
	for _, id in ipairs({ M.Strength, M.Vitality, M.Dexterity, M.Intelligence, M.Mind, M.Piety }) do
		local cur = mob:GetMod(id)
		if cur == nil or cur <= 1 then mob:SetMod(id, a) end
	end
	local mp = mob:GetMod(M.Mp)
	if mp == nil or mp <= 0 then
		if mob:IsAlly() then
			-- Story allies cast player spells, so they get player MP.
			mob:SetMod(M.Mp, stats.baseMp(mob:GetClass(), level, mob:GetMod(M.Piety) or 0))
		else
			mob:SetMod(M.Mp, stats.mobMp(level, stats.mobIsCaster(mob)))
		end
	end
	return hp
end

return stats
