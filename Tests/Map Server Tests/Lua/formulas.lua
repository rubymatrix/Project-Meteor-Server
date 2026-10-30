-- Entry points for the formula tests: battle/stats.lua called with plain numbers.

require("Battle/Stats")

local M = Modifier

-- A naked player with no equipment. points: STR, VIT, DEX, INT, MND, PIE allotted.
local function nakedPlayer(classId, level, tribeId, points)
    local p = { base = {}, playerWork = { tribe = tribeId } }
    function p:GetClass() return classId end
    function p:GetLevel() return level end
    function p:IsPlayer() return true end
    function p:GetEquipment() return nil end
    function p:HasBonusAllotment() return true end
    function p:GetBonusPoint(_, i) return points[i + 1] or 0 end
    function p:SetBaseStat(id, v) self.base[id] = v end
    return p
end

-- What the server sets for a naked player: STR, VIT, DEX, INT, MND, PIE, HP, MP, attack.
function nakedPlayerStats(classId, level, tribeId, str, vit, dex, int, mnd, pie)
    local p = nakedPlayer(classId, level, tribeId, { str, vit, dex, int, mnd, pie })
    stats.applyPlayerBaseStats(p)
    local b = p.base
    return b[M.Strength], b[M.Vitality], b[M.Dexterity], b[M.Intelligence], b[M.Mind], b[M.Piety],
        b[M.Hp], b[M.Mp], b[M.Attack]
end

function bonusPoints(level) return stats.bonusPoints(level), stats.bonusPointCap(level) end

-- The automatic split for a character with no player: points used, most in one attribute.
function bonusAllocation(classId, level)
    local sum, most = 0, 0
    for _, v in pairs(stats.bonusAllocation(classId, level)) do
        sum = sum + v
        most = math.max(most, v)
    end
    return sum, most
end

function tribe(tribeId, column) return stats.TRIBE[tribeId][column] end

function levelAdjust(userLevel, itemLevel) return stats.levelAdjust(userLevel, itemLevel) end

function mobHp(level, genusId) return stats.mobHp(level, stats.mobFamilyHpMult(genusId)) end

require("Battle/Formulas")

-- A level-typical character for the damage formulas: every attribute, attack, accuracy and DEF at
-- the class baseline, and for a player one main-hand weapon of the given Damage and delay.
local function typicalChara(classId, level, isPlayer, weaponDamage, weaponDelay)
    local e = stats.expected(isPlayer and classId or 0, level)
    local mods = {
        [M.Strength] = e.str, [M.Vitality] = e.vit, [M.Dexterity] = e.dex,
        [M.Intelligence] = e.int, [M.Mind] = e.mnd, [M.Piety] = e.pie,
        [M.Attack] = e.atk - e.str * 2 / 3,
        [M.Accuracy] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Evasion] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Defense] = isPlayer and e.gearDef or 1,
    }
    local c = {}
    function c:GetClass() return classId end
    function c:GetLevel() return level end
    function c:IsPlayer() return isPlayer end
    function c:IsMonster() return not isPlayer end
    function c:GetMod(id) return mods[id] or 0 end
    function c:GetEquipment()
        return { GetItemAtSlot = function(_, slot) return slot == stats.SLOT_MAINHAND and { itemId = 1 } or nil end }
    end
    return c, { damagePower = weaponDamage, damageInterval = weaponDelay, frequency = 1, level = 0 }
end

-- One auto-attack with no random spread. A monster attacker has no weapon arguments.
function autoAttackDamage(attackerClass, attackerLevel, weaponDamage, weaponDelay, defenderClass, defenderLevel, defenderIsPlayer)
    local attacker, weapon = typicalChara(attackerClass, attackerLevel, weaponDamage ~= nil, weaponDamage, weaponDelay)
    local defender = typicalChara(defenderClass, defenderLevel, defenderIsPlayer)
    local savedGamedata, savedVariance = GetItemGamedata, formulas.VARIANCE.physical
    GetItemGamedata = function() return weapon end
    formulas.VARIANCE.physical = 0
    local ok, dmg = pcall(formulas.physicalDamage, attacker, defender, "aa", 1.0)
    GetItemGamedata, formulas.VARIANCE.physical = savedGamedata, savedVariance
    if not ok then error(dmg) end
    return dmg
end

function levelFactor(dlvl) return formulas.levelFactor(dlvl) end
