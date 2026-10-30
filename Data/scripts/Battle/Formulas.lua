require("Modifiers")
require("Battle/Stats")

--[[
Battle math: hit, crit, parry, block and resist rates, mitigation, damage, heals, status landing,
enmity and MP cost. dlvl is target level minus actor level (positive: target is higher). Rates are
percentages (0-100), as CommandResult.hitRate and the rest expect.
--]]

formulas = formulas or {}
local M = Modifier

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
formulas.clamp = clamp

local function mod(chara, id)
	local v = chara:GetMod(id)
	return v or 0
end

formulas.VARIANCE = { physical = 0.08, magic = 0.05, heal = 0.03 }

function formulas.variance(kind)
	local v = formulas.VARIANCE[kind] or 0.05
	return 1 - v + math.random() * 2 * v
end

-- Level difference

-- Damage multiplier from level difference: -7% per level above, +5% per level below.
function formulas.levelFactor(dlvl)
	if dlvl > 0 then return math.max(0.3, 1 - 0.07 * dlvl) end
	return math.min(1.5, 1 - 0.05 * dlvl)
end

-- Rates

-- Physical hit rate, never 100%. Monsters start lower than players. Past HIT_GAP_KNEE levels
-- the rate drops HIT_GAP_STEEP per level instead of 1.5, so a Lv50 party misses a Lv58 boss about
-- one swing in eight. Accuracy-down statuses use RawHitRate, since monster Accuracy isn't modelled.
formulas.PLAYER_HIT_BASE = 95
formulas.MOB_HIT_BASE = 87
formulas.HIT_GAP_KNEE = 4
formulas.HIT_GAP_STEEP = 4.5

function formulas.hitRate(attacker, defender, skillAcc)
	local dlvl = defender:GetLevel() - attacker:GetLevel()
	local base = attacker:IsPlayer() and formulas.PLAYER_HIT_BASE or formulas.MOB_HIT_BASE
	local rate = base - 1.5 * dlvl
	if dlvl > formulas.HIT_GAP_KNEE then
		rate = rate - (formulas.HIT_GAP_STEEP - 1.5) * (dlvl - formulas.HIT_GAP_KNEE)
	end
	if dlvl < 0 then rate = base - 1.0 * dlvl end
	if attacker:IsPlayer() then
		local expA = stats.expected(stats.classOf(attacker), attacker:GetLevel())
		local accGear = mod(attacker, M.Accuracy) - stats.interp(stats.ATK_BASE_CURVE, attacker:GetLevel())
		rate = rate + 0.25 * accGear + 0.14 * (mod(attacker, M.Dexterity) - expA.dex)
	end
	if defender:IsPlayer() then
		local evaGear = mod(defender, M.Evasion) - stats.interp(stats.ATK_BASE_CURVE, defender:GetLevel())
		rate = rate - 0.25 * evaGear
	end
	rate = rate + (skillAcc or 0) + mod(attacker, M.RawHitRate) - mod(defender, M.RawEvadeRate)
	return clamp(rate, 5, 99.9)
end

-- Critical hit rate: 7.5% at dlvl 0, +0.16% per critical hit rating point. The cap stops crit gear
-- on lower targets from passing about 27%.
formulas.CRIT_RATE_CAP = 27
function formulas.critRate(attacker, defender, bonus)
	local dlvl = defender:GetLevel() - attacker:GetLevel()
	local rate
	if dlvl >= 0 then rate = 7.5 - 0.3 * dlvl else rate = 7.5 - 0.74 * dlvl end
	rate = rate + 0.16 * mod(attacker, M.CriticalHitRating) + (bonus or 0) + mod(attacker, M.RawCritRate)
	-- Critical evasion mirrors critical rating.
	rate = rate - 0.16 * mod(defender, M.CriticalHitEvasion)
	return clamp(rate, 1, formulas.CRIT_RATE_CAP)
end

-- Critical potency minus resilience, per point, added to the crit multiplier.
formulas.CRIT_POTENCY_PER_POINT = 0.00175

-- Critical damage multiplier: 1.229 at dlvl 0, cap 1.75 far below. Above, it keeps falling under
-- the 1.15 floor, so potency must first climb back to the floor: +16 shows nothing at +5.
-- magic uses Magic Critical Potency instead of Critical Attack Power. uncapped is added after the
-- clamp (Thundaga combo can exceed the cap).
formulas.CRIT_MULT_BASE = 1.229
function formulas.critMultiplier(attacker, defender, potencyBonus, magic, uncapped)
	local dlvl = defender:GetLevel() - attacker:GetLevel()
	local m
	if dlvl >= 0 then m = formulas.CRIT_MULT_BASE - 0.0214 * dlvl else m = formulas.CRIT_MULT_BASE - 0.03 * dlvl end
	local pot, res
	if magic then
		pot, res = mod(attacker, M.MagicCriticalHitPotency), mod(defender, M.MagicCriticalHitResilience)
	else
		pot, res = mod(attacker, M.CriticalHitAttackPower), mod(defender, M.CriticalHitResilience)
	end
	m = m + (potencyBonus or 0) + formulas.CRIT_POTENCY_PER_POINT * (pot - res)
	-- The 115% floor applies after potency.
	return clamp(m, 1.15, 1.75) + (uncapped or 0)
end

-- Parry: players without a shield, not from behind. Monsters never parry or block.
function formulas.parryRate(attacker, defender)
	if not defender:IsPlayer() then return 0 end
	if mod(defender, M.CanBlock) ~= 0 then return 0 end
	local dAtk = attacker:GetLevel() - defender:GetLevel()
	local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
	-- Parry gear and DEX move it only a little; level matters more.
	local rate = 4 - 0.3 * dAtk + 0.04 * mod(defender, M.Parry)
	if defender:IsPlayer() then rate = rate + 0.02 * (mod(defender, M.Dexterity) - exp.dex) end
	return clamp(rate + mod(defender, M.RawParryRate), 0, 30)
end

-- Fraction of damage a parry removes.
formulas.PARRY_REDUCTION = 0.5

-- Block: shield only, not from behind. Base(dlvl) + 0.1% per DEX + 0.2% per Block Rate, cap 75%.
function formulas.blockRate(attacker, defender)
	if not defender:IsPlayer() then return 0 end
	if mod(defender, M.CanBlock) == 0 then return 0 end
	local dAtk = attacker:GetLevel() - defender:GetLevel()
	-- DEX counts above the level-typical value, so a Lv1 and a Lv50 GLA with typical stats block
	-- equally often.
	local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
	local rate = 20 - 1.0 * dAtk + 0.1 * (mod(defender, M.Dexterity) - exp.dex) + 0.2 * mod(defender, M.BlockRate)
	return clamp(rate + mod(defender, M.RawBlockRate), 0, 75)
end

-- Block damage reduction: base(dlvl) + 0.1% per VIT + 0.2% per Block, 20-75%. VIT counts above the
-- level-typical value to keep Lv1 and Lv50 comparable.
function formulas.blockReduction(attacker, defender)
	local dAtk = attacker:GetLevel() - defender:GetLevel()
	local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
	local r = 56 - 1.25 * dAtk + 0.1 * (mod(defender, M.Vitality) - exp.vit) + 0.2 * mod(defender, M.Block)
	return clamp(r, 20, 75) / 100
end

-- Magic partial-resist chance (each tier -25%). MACC and MEVA count above the level-typical value,
-- as hitRate does for accuracy. Monsters have no MagicEvasion stat, so they read as level-typical
-- plus any status mod; a raw player MACC would otherwise leave them never resisting.
local function typicalMagic(chara, attr)
	local e = stats.expected(chara:IsPlayer() and stats.classOf(chara) or 0, chara:GetLevel())
	return e.magic + (e[attr] or 0) / 4
end

-- Half a point per MEVA, no cap: about 200 MEVA takes a caster from never to always resisted.
formulas.RESIST_PER_POINT = 0.5

function formulas.resistRate(attacker, defender)
	local dlvl = defender:GetLevel() - attacker:GetLevel()
	local rate = 10 + 2 * dlvl
	local meva = defender:IsPlayer() and mod(defender, M.MagicEvasion)
		or (typicalMagic(defender, "pie") + mod(defender, M.MagicEvasion))
	local macc = attacker:IsPlayer() and mod(attacker, M.MagicAccuracy)
		or (typicalMagic(attacker, "mnd") + mod(attacker, M.MagicAccuracy))
	rate = rate + formulas.RESIST_PER_POINT * ((meva - typicalMagic(defender, "pie")) - (macc - typicalMagic(attacker, "mnd")))
	return clamp(rate + mod(defender, M.RawResistRate), 0, 100)
end

-- Mitigation

-- Monsters get the level-typical value.
function formulas.effectiveDefense(chara)
	if chara:IsPlayer() then
		return math.max(0, mod(chara, M.Defense)) + 0.67 * mod(chara, M.Vitality)
	end
	-- Monster Defense mods are 1 by default; the rest is a status (Defense Down, Protect) or an
	-- authored bonus. Only the total is floored, so Defense Down still counts.
	local e = stats.expected(0, chara:GetLevel())
	return math.max(0, e.def + mod(chara, M.Defense) - 1)
end

-- Fraction of physical damage a monster's DEF removes. A level-typical monster always takes 25%
-- less. Players take a flat subtraction instead (defendedHit).
function formulas.defenseReduction(defender)
	local def = formulas.effectiveDefense(defender)
	local exp = stats.expected(stats.classOf(defender), defender:GetLevel()).def
	return def / (def + 3 * math.max(exp, 1))
end

-- Flat amount taken off every physical hit on a monster more than GAP_DEF_FREE_LEVELS above the
-- attacker, scaled by its DEF. A flat cut hits auto-attacks far harder than weaponskills: a Lv50
-- DRG's swings on a Lv58 boss do a fifth of its weaponskills. Players are not affected.
formulas.GAP_DEF_FREE_LEVELS = 4
formulas.GAP_DEF_PER_LEVEL = 0.34
-- Floor as a share of the hit, so weak swings still land and draw enmity.
formulas.GAP_DEF_MIN_SHARE = 0.22

-- Damage a player's effective DEF removes from a hit, per point, by how many levels the attacker
-- is above. The slope steepens with the gap and does not depend on the monster family.
formulas.DEF_SLOPE = { {0, 0.237}, {2, 0.295}, {8, 0.526}, {9, 0.565} }
-- The slope is per DEF point at Lv50. Lower-level gear holds far less DEF, so a point there
-- counts for more: the slope grows with (typical Lv50 DEF / typical DEF)^DEF_LEVEL_EXP.
formulas.DEF_LEVEL_EXP = 0.33
-- No amount of DEF takes a hit below this share of it.
formulas.DEF_FLOOR_SHARE = 0.117
-- Monster hits on players before DEF, against the same hit on a monster. Players carry far more
-- DEF than the 25% a monster's removes, so the raw hit is larger.
formulas.MOB_HIT_ON_PLAYER = 2.62

function formulas.defenseSlope(attacker, defender)
	local k = stats.interp(formulas.DEF_SLOPE, attacker:GetLevel() - defender:GetLevel())
	local typical = math.max(stats.expected(0, defender:GetLevel()).def, 1)
	return math.max(0, k) * (stats.expected(0, 50).def / typical) ^ formulas.DEF_LEVEL_EXP
end

-- A hit on a player after DEF: hit minus slope x effective DEF, never below the floor share.
function formulas.defendedHit(attacker, defender, hit)
	local cut = formulas.defenseSlope(attacker, defender) * formulas.effectiveDefense(defender)
	return math.max(hit - cut, hit * formulas.DEF_FLOOR_SHARE)
end

function formulas.levelGapDefense(attacker, defender)
	if defender:IsPlayer() then return 0 end
	local lv = defender:GetLevel()
	local over = (lv - attacker:GetLevel()) - formulas.GAP_DEF_FREE_LEVELS
	if over <= 0 then return 0 end
	local typical = stats.expected(0, lv).def
	local scale = typical > 0 and formulas.effectiveDefense(defender) / typical or 1
	return formulas.GAP_DEF_PER_LEVEL * over * stats.referenceWeaponDamage(lv) * scale
end

-- Damage

-- Primary and secondary attribute per class for physical attacks.
formulas.WEAPON_STATS = {
	[2]  = { M.Strength, M.Intelligence },
	[3]  = { M.Strength, M.Mind },
	[4]  = { M.Strength, M.Vitality },
	[7]  = { M.Piety, M.Dexterity },
	[8]  = { M.Strength, M.Piety },
	[22] = { M.Mind, M.Piety },
	[23] = { M.Mind, M.Piety },
}
local ATTR_KEY = { [M.Strength] = "str", [M.Vitality] = "vit", [M.Dexterity] = "dex",
				   [M.Intelligence] = "int", [M.Mind] = "mnd", [M.Piety] = "pie" }

-- Attribute caps, set by the weapon's DPS ((Damage + bow ammo) / Delay). Auto-attack-class hits
-- (auto-attack, Light Shot, Jump, Throw) cap both at 280, never above the weaponskill cap. Below
-- Lv50 the caps sit far above typical attributes. Past the cap STR still adds attack.
formulas.AA_STAT_CAP = 280
-- Secondary caps measured at five weapons climb faster than one line through them; below the
-- lowest the line's 5 per DPS holds.
formulas.WS_SECONDARY_CAP = { {34.62, 280}, {36.74, 297}, {39.7, 307}, {40.0, 311}, {42.06, 317.5} }

function formulas.statCaps(attacker, kind, w)
	w = w or stats.weapon(attacker)
	local dps = w.dps or 0
	local capP = 318 + 6 * (dps - 34.62)
	local capS
	if dps <= 34.62 then capS = 280 + 5 * (dps - 34.62) else capS = stats.interp(formulas.WS_SECONDARY_CAP, dps) end
	if kind ~= "ws" then
		capP = math.min(formulas.AA_STAT_CAP, capP)
		capS = math.min(formulas.AA_STAT_CAP, capS)
	end
	return math.max(capP, 1), math.max(capS, 1)
end

function formulas.physicalStatRatio(attacker, kind, w)
	if not attacker:IsPlayer() then return 1 end
	local classId = stats.classOf(attacker)
	local pair = formulas.WEAPON_STATS[classId] or { M.Strength, M.Vitality }
	local exp = stats.expected(classId, attacker:GetLevel())
	local pExp, sExp = exp[ATTR_KEY[pair[1]]], exp[ATTR_KEY[pair[2]]]
	local capP, capS = formulas.statCaps(attacker, kind or "ws", w)
	local p = math.min(mod(attacker, pair[1]), capP)
	local s = math.min(mod(attacker, pair[2]), capS)
	-- A weapon whose cap sits below the typical stat must not read as a deficit beyond the cap.
	pExp, sExp = math.min(pExp, capP), math.min(sExp, capS)
	local atk = mod(attacker, M.Attack) + mod(attacker, M.Strength) * 2 / 3
	local num = 0.8 * p + 0.68 * s + 0.38 * atk
	local den = 0.8 * pExp + 0.68 * sExp + 0.38 * exp.atk
	if den <= 0 then return 1 end
	return clamp(num / den, 0.25, 2.5)
end

-- Auto-attacks key off weapon Damage, not DPS.
formulas.AA_PER_DAMAGE = 1.6

-- Weaponskills key off weapon DPS.
formulas.WS_PER_DPS = 12.0

-- Delay exponents, normalised at a 3.0 s weapon: slower weapons hit harder per action.
formulas.AA_DELAY_EXP = 0.55
formulas.WS_DELAY_EXP = 0.72

-- Player physical damage grows faster with level than weapon Damage alone: flat to Lv27, then
-- x1.68 by Lv50, where +1 weapon Damage adds about 2 to an auto-attack.
formulas.PLAYER_LEVEL_SCALE = { {27, 1.0}, {50, 1.68} }

-- A magnitude-1000 spell at stat ratio 1 does this times a level-typical weapon Damage. Up to
-- Lv27 a level-matched nuke lands near one level-matched weaponskill (Thunder ~ Fast Blade); it
-- then rises so a level-typical Lv50 Fire does about 295 to an even target.
formulas.SPELL_UNIT_PER_DAMAGE = { {27, 2.8}, {50, 3.66} }

-- kind is "aa" or "ws"; potency 1.0 is the reference opener. slot defaults to the main hand
-- (Throw passes the throwing weapon). C# applies crit, block and parry afterwards.
function formulas.physicalDamage(attacker, defender, kind, potency, slot)
	local w = stats.weapon(attacker, slot)
	local base
	local delayRatio = math.max(w.delay, 0.5) / 3.0
	if kind == "ws" then
		base = formulas.WS_PER_DPS * w.dps * delayRatio ^ formulas.WS_DELAY_EXP
	else
		base = formulas.AA_PER_DAMAGE * w.damage * delayRatio ^ formulas.AA_DELAY_EXP
	end
	local hit = base * formulas.physicalStatRatio(attacker, kind, w)
	hit = hit * formulas.levelFactor(defender:GetLevel() - attacker:GetLevel())
	local dmg
	if attacker:IsPlayer() then hit = hit * stats.interp(formulas.PLAYER_LEVEL_SCALE, attacker:GetLevel()) end
	if defender:IsPlayer() then
		-- Potency scales the hit after DEF, so DEF takes the same share off weaponskills.
		hit = hit * formulas.MOB_HIT_ON_PLAYER
		dmg = (potency or 1) * formulas.defendedHit(attacker, defender, hit) * formulas.variance("physical")
	else
		dmg = hit * (potency or 1) * (1 - formulas.defenseReduction(defender))
		dmg = dmg * formulas.variance("physical")
		dmg = math.max(dmg - formulas.levelGapDefense(attacker, defender), dmg * formulas.GAP_DEF_MIN_SHARE)
	end
	dmg = dmg * (1 - mod(defender, M.DamageTakenDown) / 100)
	return math.max(1, math.floor(dmg))
end

-- The client's per-spell stat pairs only weight the attributes here; their exact role is unknown.
-- statsOnly uses the pairs alone: Dragonfire Dive is PIE-keyed and must not depend on attack magic
-- potency a lancer never builds. The stat pair weighs more than potency: potency is mostly gear,
-- and level-typical stats here stand for a geared caster.
formulas.SPELL_AMP_WEIGHT = 0.5
formulas.SPELL_STAT_WEIGHT = 0.85

function formulas.magicStatRatio(caster, statWeights, statsOnly)
	if not caster:IsPlayer() then return 1 end
	local exp = stats.expected(stats.classOf(caster), caster:GetLevel())
	local amp = mod(caster, M.AttackMagicPotency)
	local ampExp = exp.magic + exp.int / 4
	local r = amp / math.max(ampExp, 1)
	if statWeights then
		local num, den = 0, 0
		for id, wgt in pairs(statWeights) do
			num = num + wgt * mod(caster, id)
			den = den + wgt * exp[ATTR_KEY[id]]
		end
		if den > 0 then
			if statsOnly then
				r = num / den
			else
				r = 1 + formulas.SPELL_AMP_WEIGHT * (r - 1) + formulas.SPELL_STAT_WEIGHT * (num / den - 1)
			end
		end
	end
	return clamp(r, 0.25, 2.5)
end

function formulas.spellUnit(level)
	return stats.interp(formulas.SPELL_UNIT_PER_DAMAGE, level) * stats.referenceWeaponDamage(level)
end

-- Spell level factor. Targets below the caster take far more than levelFactor allows: x4.1 at 15
-- levels down, x6.7 at 49. Above the caster it falls gently (0.72 at +8), since spells skip DEF and
-- levelGapDefense and this one factor carries the whole gap.
formulas.SPELL_LEVEL_BELOW = { {0, 1.0}, {5, 1.25}, {10, 2.2}, {15, 4.1}, {49, 6.7} }
formulas.SPELL_ABOVE_PER_LEVEL = 0.035

function formulas.spellLevelFactor(dlvl)
	if dlvl >= 0 then return math.max(0.3, 1 - formulas.SPELL_ABOVE_PER_LEVEL * dlvl) end
	return math.min(6.7, stats.interp(formulas.SPELL_LEVEL_BELOW, -dlvl))
end

function formulas.spellDamage(caster, target, magnitude, statWeights, statsOnly)
	local dmg = (magnitude / 1000) * formulas.spellUnit(caster:GetLevel())
	dmg = dmg * formulas.magicStatRatio(caster, statWeights, statsOnly)
	dmg = dmg * formulas.spellLevelFactor(target:GetLevel() - caster:GetLevel())
	dmg = dmg * (1 - mod(target, M.DamageTakenDown) / 100)
	-- MagicResistance: % less attack-spell damage (Magic Resistance Up, wards).
	dmg = dmg * (1 - clamp(mod(target, M.MagicResistance), 0, 100) / 100)
	dmg = dmg * formulas.variance("magic")
	return math.max(1, math.floor(dmg))
end

-- Healing spell amount. Only a CNJ main class gets the MND term. Cure is magnitude 1000, Cura 2000,
-- Curaga 4000.
function formulas.healAmount(caster, target, magnitude)
	local hmp = mod(caster, M.HealingMagicPotency)
	local classId = stats.classOf(caster)
	local amount
	if classId == stats.CLASS.CNJ then
		amount = 1.15 * hmp + 0.2 * mod(caster, M.Mind)
	else
		amount = 1.03 * hmp
	end
	amount = amount + 0.05 * mod(caster, M.Vitality)
	amount = amount * (magnitude / 1000) * formulas.variance("heal")
	return math.max(1, math.floor(amount))
end

-- Heals crit on the damage curves at dlvl 0, with magic crit rating and potency. A THM main class
-- crits its cures more often.
formulas.HEAL_CRIT_THM_BONUS = 3.3
function formulas.healCrit(caster)
	local rate = 7.5 + 0.16 * mod(caster, M.MagicCriticalHitRating) + mod(caster, M.RawCritRate)
	if stats.classOf(caster) == stats.CLASS.THM then rate = rate + formulas.HEAL_CRIT_THM_BONUS end
	if math.random() * 100 >= clamp(rate, 1, formulas.CRIT_RATE_CAP) then return 1.0 end
	return clamp(formulas.CRIT_MULT_BASE + formulas.CRIT_POTENCY_PER_POINT * mod(caster, M.MagicCriticalHitPotency), 1.15, 1.75)
end

-- Monster elemental affinity and directional weakness

-- ActionProperty (CommandResult.cs) names -> ids; elements are 5..10.
formulas.ELEMENT_ID = { Fire = 5, Ice = 6, Wind = 7, Earth = 8, Lightning = 9, Water = 10 }

function formulas.elementOf(skill)
	local ok, p = pcall(function() return tostring(skill.actionProperty) end)
	if not ok or p == nil then return nil end
	return formulas.ELEMENT_ID[p] or tonumber(p)
end

local function mobMod(target, id)
	local ok, v = pcall(function() return target:GetMobMod(id) end)
	if ok and v ~= nil then return tonumber(v) or 0 end
	return 0
end

-- Mob mods 30..35 (25 + element id) hold the percent per element, from genus_mods. Own element
-- -30, the element that beats it +20. Physical hits never call this.
function formulas.affinityMult(target, element)
	if element == nil or element < 5 or element > 10 then return 1.0 end
	local ok, mob = pcall(function() return target:IsMonster() end)
	if not ok or not mob then return 1.0 end
	return math.max(0, 1 + mobMod(target, 25 + element) / 100)
end

-- Directional weakness: mob mod WeakDirection (36) is a HitDirection mask, WeakDirectionBonus (37)
-- a percent. No rows set them yet. The Exposed statuses (front/right/rear/left) give +50% damage
-- from that side; nothing applies them yet.
formulas.EXPOSED = { [1] = 223017, [2] = 223018, [4] = 223019, [8] = 223020 }
formulas.EXPOSED_BONUS = 0.5

function formulas.directionMult(target, hitDirection)
	if hitDirection ~= nil and formulas.EXPOSED[hitDirection] ~= nil then
		local okE, exposed = pcall(function() return target.statusEffects:HasStatusEffect(formulas.EXPOSED[hitDirection]) end)
		if okE and exposed then return 1 + formulas.EXPOSED_BONUS end
	end
	local ok, mob = pcall(function() return target:IsMonster() end)
	if not ok or not mob or hitDirection == nil or hitDirection == 0 then return 1.0 end
	local mask = math.floor(mobMod(target, 36))
	if mask == 0 then return 1.0 end
	-- bit test without bit32 (MoonSharp has it, plain Lua 5.4 does not)
	if math.floor(mask / hitDirection) % 2 == 1 then
		return 1 + mobMod(target, 37) / 100
	end
	return 1.0
end

-- Status landing (enfeebles and additional effects)

-- Each point of a status resistance counts as one point of magic evasion against that status.
formulas.STATUS_RESIST_MOD = {
	[223003] = M.SlowResistance, [223004] = M.PetrificationResistance, [223005] = M.ParalysisResistance,
	[223006] = M.SilenceResistance, [223007] = M.BlindResistance, [223011] = M.PoisonResistance,
	[223015] = M.StunResistance, [228001] = M.SleepResistance, [228011] = M.BindResistance,
	[228021] = M.HeavyResistance,
}

-- Landing chance (0-1) for a hostile status: Enfeebling Magic Potency (magic accuracy with
-- useMacc, for Sleep and Repose) against the target's magic evasion, both above level-typical.
-- Pure enfeebles cap at 75%; riders on damaging actions can still reach a listed chance of 1.0.
formulas.ENFEEBLE_CAP = 0.75
function formulas.statusLandChance(caster, target, statusId, baseChance, kind, useMacc)
	local chance = baseChance or 0
	if chance <= 0 then return 0 end
	local dlvl = target:GetLevel() - caster:GetLevel()
	local delta = 0
	if caster:IsPlayer() then
		local exp = stats.expected(stats.classOf(caster), caster:GetLevel())
		if useMacc then
			delta = mod(caster, M.MagicAccuracy) - (exp.magic + exp.mnd / 4)
		else
			delta = mod(caster, M.EnfeeblingMagicPotency) - (exp.magic + exp.pie / 4)
		end
	end
	local resist = 0
	if target:IsPlayer() then
		local exp = stats.expected(stats.classOf(target), target:GetLevel())
		resist = mod(target, M.MagicEvasion) - (exp.magic + exp.pie / 4)
	end
	local sr = formulas.STATUS_RESIST_MOD[statusId]
	if sr ~= nil then resist = resist + mod(target, sr) end
	chance = chance * (1 + 0.004 * (delta - resist)) - 0.03 * math.max(0, dlvl)
	-- Riders may rise up to 15 points over their listed chance.
	local cap = (kind == "enfeeble") and formulas.ENFEEBLE_CAP or math.min(1.0, baseChance + 0.15)
	return clamp(chance, 0.05, cap)
end

-- Enmity

-- Enmity per HP healed; 1 damage is 1 enmity.
formulas.HEAL_ENMITY = 0.6

-- Fixed-enmity abilities give their Lv50 value scaled linearly by level.
function formulas.fixedEnmity(atLv50, level)
	return math.max(10, math.floor(atLv50 * level / 50))
end

-- MP cost, as the client's calculateCommandCost
function formulas.commandCostBase(level)
	if level <= 10 then return 100 + level * 10 end
	if level <= 20 then return 200 + (level - 10) * 20 end
	if level <= 30 then return 400 + (level - 20) * 40 end
	if level <= 40 then return 800 + (level - 30) * 70 end
	return 1500 + (level - 40) * 130
end

function formulas.mpCost(level, permille)
	return math.ceil(formulas.commandCostBase(level) * permille * 0.001)
end

return formulas
