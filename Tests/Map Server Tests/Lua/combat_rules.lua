-- Entry points for the combat rule tests: command and status scripts run against stand-in actors.

require("Global")
require("Modifiers")
require("BattleUtils")
require("Battle/Stats")
require("Battle/Formulas")
require("Battle/Actions")
require("Battle/Ko")
require("Battle/Partybonus")
require("Battle/Buffs")
require("Battle/Items")

local M = Modifier
local harness = getfenv(1)

-- Each game script gets its own globals so their onGain/onSkillFinish don't collide.
local function load(path)
    local fh = assert(io.open("./scripts/" .. path .. ".lua", "r"))
    local src = fh:read("*a")
    fh:close()
    local f = assert(loadstring(src, "@" .. path))
    local env = setmetatable({}, { __index = harness })
    setfenv(f, env)
    f()
    return env
end

local nextId = 1000

-- A stand-in character. Stats are level-typical for its class unless opts.mods overrides them.
local function chara(opts)
    opts = opts or {}
    nextId = nextId + 1
    local classId, level = opts.class or 3, opts.level or 50
    local isPlayer = opts.player ~= false
    local e = stats.expected(isPlayer and classId or 0, level)
    local c = {
        Id = nextId,
        base = opts.base or {},
        mods = {
            [M.Strength] = e.str, [M.Vitality] = e.vit, [M.Dexterity] = e.dex,
            [M.Intelligence] = e.int, [M.Mind] = e.mnd, [M.Piety] = e.pie,
            [M.Attack] = e.atk - e.str * 2 / 3,
            [M.Accuracy] = stats.interp(stats.ATK_BASE_CURVE, level),
            [M.Evasion] = stats.interp(stats.ATK_BASE_CURVE, level),
            [M.Defense] = isPlayer and e.gearDef or 1,
        },
        layers = {},
        hp = opts.hp or 2000, maxHp = opts.maxHp or opts.hp or 2000,
        mp = opts.mp or 1000, maxMp = opts.maxMp or opts.mp or 1000,
        tp = 0,
        traits = opts.traits or {},
        equipped = opts.equipped or {},
        log = {},
        autoAttackBaseHits = opts.baseHits,
        positionX = opts.x or 0, positionY = 0, positionZ = opts.z or 0,
    }
    for id, v in pairs(opts.mods or {}) do c.mods[id] = v end

    function c:GetClass() return classId end
    function c:GetLevel() return level end
    function c:IsPlayer() return isPlayer end
    function c:IsMonster() return not isPlayer end
    function c:IsAlive() return true end
    function c:IsDead() return opts.dead == true end
    function c:GetEquipment()
        if not isPlayer then return nil end
        return { GetItemAtSlot = function(_, slot) return slot == stats.SLOT_MAINHAND and { itemId = 1 } or nil end }
    end
    function c:GetBaseStat(id) return self.base[id] or 0 end
    function c:SetStatLayer(layer, id, v)
        self.layers[layer] = self.layers[layer] or {}
        self.layers[layer][id] = v
    end
    function c:Layer(layer, id) return (self.layers[layer] or {})[id] or 0 end
    function c:GetMod(id)
        local v = (self.base[id] or 0) + (self.mods[id] or 0)
        for _, l in pairs(self.layers) do v = v + (l[id] or 0) end
        return v
    end
    function c:SetMod(id, v) self.mods[id] = v end
    function c:AddMod(id, v) self.mods[id] = (self.mods[id] or 0) + v end
    function c:SubtractMod(id, v) self.mods[id] = (self.mods[id] or 0) - v end
    function c:GetHP() return self.hp end
    function c:GetMaxHP() return self.maxHp end
    function c:SetHP(v) self.hp = v end
    function c:SetMaxHP(v) self.maxHp = v end
    function c:GetHPP() return math.floor(100 * self.hp / self.maxHp) end
    function c:AddHP(v) self.log.addHp = (self.log.addHp or 0) + v; self.hp = self.hp + v end
    function c:DelHP(v) self.log.delHp = (self.log.delHp or 0) + v; self.hp = self.hp - v end
    function c:GetMP() return self.mp end
    function c:GetMaxMP() return self.maxMp end
    function c:SetMP(v) self.mp = v end
    function c:SetMaxMP(v) self.maxMp = v end
    function c:AddMP(v) self.log.addMp = (self.log.addMp or 0) + v; self.mp = self.mp + v end
    function c:DelMP(v) self.log.delMp = (self.log.delMp or 0) + v; self.mp = self.mp - v end
    function c:AddTP(v) self.tp = self.tp + v end
    function c:GetTP() return self.tp end
    function c:HasTrait(id) return self.traits[id] == true end
    function c:HasItemEquippedInSlot(item, slot) return self.equipped[item] == slot end
    function c:GetPos() return { [0] = self.positionX, [1] = self.positionY, [2] = self.positionZ } end
    function c:OfferRaise(raiser, hpPercent, weakness)
        self.log.raiseHp, self.log.raiseWeakness = hpPercent, weakness
    end
    function c:GetMobMod() return 0 end

    -- Status container: effects by id, with every add and remove recorded.
    local effects = {}
    c.added, c.removed = {}, {}
    c.statusEffects = {
        GetStatusEffectById = function(_, id) return effects[id] end,
        HasStatusEffect = function(_, id) return effects[id] ~= nil end,
        RemoveStatusEffect = function(_, x)
            local id = type(x) == "table" and x.id or x
            c.removed[#c.removed + 1] = id
            effects[id] = nil
        end,
        AddStatusEffect = function(_, id, tier, magnitude, duration)
            if type(id) == "table" then
                local se = id
                c.added[#c.added + 1] = { id = se.id, magnitude = se.magnitude, duration = se.duration }
                effects[se.id] = se
                return true
            end
            c.added[#c.added + 1] = { id = id, tier = tier, magnitude = magnitude, duration = duration }
            return true
        end,
    }
    function c:Give(effect) effects[effect.id] = effect; return effect end

    -- Hate list: total change per actor id.
    c.hate = {}
    c.hateContainer = {
        UpdateHate = function(_, who, amount) c.hate[who.Id] = (c.hate[who.Id] or 0) + amount end,
        HasHateForTarget = function(_, who) return c.hate[who.Id] ~= nil end,
        AddBaseHate = function(_, who) c.hate[who.Id] = c.hate[who.Id] or 0 end,
        GetHateList = function()
            return setmetatable({}, { __index = function(_, who) return { cumulativeEnmity = c.hate[who.Id] or 0 } end })
        end,
    }
    function c:Hates(who, amount) self.hate[who.Id] = amount or 0 end
    return c
end

-- Actors standing around `who`, as the iterator GetActorsAroundActor gives Lua.
local function area(list)
    return {
        GetActorsAroundActor = function()
            local i = 0
            return function() i = i + 1; return list[i] end
        end,
    }
end

local function effect(id, opts)
    opts = opts or {}
    local e = { id = id, tier = opts.tier or 1, magnitude = opts.magnitude or 0, extra = 0, source = opts.source }
    function e:GetTier() return self.tier end
    function e:GetMagnitude() return self.magnitude end
    function e:SetMagnitude(v) self.magnitude = v end
    function e:SetDuration(v) self.duration = v end
    function e:SetOwner(o) self.owner = o end
    function e:GetSource() return self.source end
    function e:SetExtra(v) self.extra = v end
    function e:GetExtra() return self.extra end
    function e:GetStatusId() return self.id end
    return e
end

local function skill(opts)
    opts = opts or {}
    local s = {
        id = opts.id or 0, commandType = opts.commandType or CommandType.Weaponskill,
        actionType = opts.actionType or ActionType.Physical,
        castTimeMs = opts.castTimeMs or 0, recastTimeMs = opts.recastTimeMs or 0,
        statusId = opts.statusId or 0, statusChance = opts.statusChance or 0,
        statusDuration = opts.statusDuration or 0, statusMagnitude = 0, statusTier = 1,
        isCombo = opts.combo == true, comboStep = opts.combo and 2 or 0,
        accuracyModifier = 0, basePotency = 100, bonusCritRate = 0, numHits = 1,
    }
    function s:GetCommandType() return self.commandType end
    function s:GetActionType() return self.actionType end
    function s:GetTargets() return nil end
    return s
end

local function action(opts)
    opts = opts or {}
    local a = { amount = opts.amount or 0, enmity = opts.enmity or 0, param = opts.param or 0, amountMitigated = opts.amountMitigated or 0 }
    function a:DoAction(caster, target, sk) self.done = true; self.chanceAtAction = sk and sk.statusChance end
    function a:TryStatus() end
    function a:ActionLanded() return true end
    return a
end

local function container()
    local k = { entries = {} }
    local function add(_, ...) k.entries[#k.entries + 1] = { ... } end
    k.AddHPAbsorbAction, k.AddHPAction, k.AddMPAction, k.AddAction = add, add, add, add
    return k
end

-- Runs fn with no random damage spread, and a weapon of the given Damage and delay.
local function steady(fn, weaponDamage, delay)
    local savedGamedata, savedVariance = GetItemGamedata, formulas.VARIANCE
    harness.GetItemGamedata = function()
        return { damagePower = weaponDamage or 60, damageInterval = delay or 3.0, frequency = 1, level = 0 }
    end
    formulas.VARIANCE = { physical = 0, magic = 0, heal = 0 }
    local ok, r1, r2, r3, r4 = pcall(fn)
    harness.GetItemGamedata, formulas.VARIANCE = savedGamedata, savedVariance
    if not ok then error(r1) end
    return r1, r2, r3, r4
end

-- Runs fn with GetWorldManager giving status rows built from `effect`.
local function withStatusRows(fn)
    local saved = GetWorldManager
    harness.GetWorldManager = function()
        return { GetStatusEffect = function(_, id) return effect(id) end }
    end
    local ok, r1, r2, r3, r4 = pcall(fn)
    harness.GetWorldManager = saved
    if not ok then error(r1) end
    return r1, r2, r3, r4
end

------------------------------------------------------------------------------
-- Enmity
------------------------------------------------------------------------------

-- action.enmity from an ability script on one mob. statusId: a status the caster has up.
function abilityEnmity(script, level, statusId)
    local caster, target = chara({ level = level }), chara({ level = level, player = false })
    if statusId and statusId > 0 then caster:Give(effect(statusId)) end
    local s = load(script)
    local a = action()
    s.onSkillFinish(caster, target, skill({ commandType = CommandType.Ability }), a, container())
    return a.enmity
end

-- Hate change on each of two mobs that hate the caster, from a self-targeted ability script.
function areaEnmity(script, level)
    local caster = chara({ level = level })
    local m1, m2 = chara({ level = level, player = false }), chara({ level = level, player = false })
    m1:Hates(caster, 0)
    m2:Hates(caster, 0)
    caster.CurrentArea = area({ m1, m2 })
    local s = load(script)
    s.onSkillFinish(caster, caster, skill({ commandType = CommandType.Ability }), action(), container())
    return m1.hate[caster.Id] or 0, m2.hate[caster.Id] or 0
end

-- Same with a single mob.
function singleMobEnmity(script, level)
    local caster = chara({ level = level })
    local m1 = chara({ level = level, player = false })
    m1:Hates(caster, 0)
    caster.CurrentArea = area({ m1 })
    local s = load(script)
    s.onSkillFinish(caster, caster, skill({ commandType = CommandType.Ability }), action(), container())
    return m1.hate[caster.Id] or 0
end

-- Enmity of a damaging weaponskill script minus its damage: the flat part.
function flatWeaponskillEnmity(script, level)
    local caster, target = chara({ level = level }), chara({ level = level, player = false })
    local a = action()
    steady(function()
        load(script).onSkillFinish(caster, target, skill(), a, container())
    end)
    return a.enmity - a.amount, a.amount
end

-- Enmity per point of damage on a comboed hit.
function comboEnmityRatio(script, mnd)
    local mods = mnd and { [M.Mind] = mnd } or nil
    local caster, target = chara({ level = 50, mods = mods }), chara({ level = 50, player = false })
    local a = action()
    steady(function()
        load(script).onSkillFinish(caster, target, skill({ combo = true }), a, container())
    end, 90, 3.0)
    return a.enmity / a.amount, a.amount
end

-- Freeze: action.enmity from its damage and the change on a mob holding 10000 hate.
function freezeEnmity(level)
    local caster, target = chara({ class = 22, level = level }), chara({ level = level, player = false })
    target:Hates(caster, 10000)
    local a = action()
    steady(function()
        load("Command/Magic/Freeze").onSkillFinish(caster, target,
            skill({ commandType = CommandType.Spell, actionType = ActionType.Magic }), a, container())
    end)
    return a.enmity, target.hate[caster.Id] - 10000, a.amount
end

-- actions.enmityScale with the given statuses up and Modifier.Enmity points.
function enmityScale(sentinel, antagonizeTier, enmityPoints)
    local caster = chara({ mods = { [M.Enmity] = enmityPoints or 0 } })
    if sentinel then caster:Give(effect(223062)) end
    if antagonizeTier and antagonizeTier > 0 then caster:Give(effect(223251, { tier = antagonizeTier })) end
    return actions.enmityScale(caster)
end

-- Heal enmity: HP restored and action.enmity. missing: HP the target lacks.
function healEnmity(amount, missing, sentinel)
    local caster = chara({ class = 23 })
    local target = chara({ hp = 3000 - missing, maxHp = 3000 })
    if sentinel then caster:Give(effect(223062)) end
    local a = action()
    local restored = actions.healSpell(caster, target, skill({ commandType = CommandType.Spell, actionType = ActionType.Heal }),
        a, container(), { amount = amount })
    return a.enmity, restored
end

-- Shroud of Saints on an action that would make `enmity`.
function shroudEnmity(enmity)
    local s = load("Status/ShroudOfSaints")
    local caster = chara()
    local a = action({ enmity = enmity })
    s.onPreAction(effect(223226), caster, chara({ player = false }), skill(), a, container())
    return a.enmity
end

------------------------------------------------------------------------------
-- KO
------------------------------------------------------------------------------

-- Max HP and MP after Status/Weakness onGain, from base HP/MP.
function weakness(baseHp, baseMp)
    local p = chara({ base = { [M.Hp] = baseHp, [M.Mp] = baseMp }, hp = baseHp, mp = baseMp })
    load("Status/Weakness").onGain(p, effect(ko.WEAKNESS), container())
    return p:GetMaxHP(), p:GetMaxMP(), ko.PENALTY_SECONDS
end

-- Status/BrinkOfDeath onGain: the stat after the penalty, as a share of before, for each
-- of HP, MP, Attack, Attack Magic Potency, Defense, Fire Resistance.
function brinkShares()
    local base = { [M.Hp] = 2000, [M.Mp] = 1000, [M.Attack] = 400, [M.AttackMagicPotency] = 300,
        [M.Defense] = 500, [M.FireResistance] = 100 }
    local p = chara({ base = base, mods = { [M.Attack] = 0, [M.Defense] = 0 }, hp = 2000, mp = 1000 })
    local ids = { M.Hp, M.Mp, M.Attack, M.AttackMagicPotency, M.Defense, M.FireResistance }
    local before = {}
    for i, id in ipairs(ids) do before[i] = p:GetMod(id) end
    load("Status/BrinkOfDeath").onGain(p, effect(ko.BRINK_OF_DEATH), container())
    local out = {}
    for i, id in ipairs(ids) do out[i] = p:GetMod(id) / before[i] end
    return out[1], out[2], out[3], out[4], out[5], out[6]
end

-- ko.applyRevivePenalty on a player holding `current` (0, Weakness or Brink). Returns the id
-- applied, the duration it was given, how many statuses were added, and 1 if Weakness was removed.
function revivePenalty(current, kind, penalty)
    local p = chara()
    if current ~= 0 then p:Give(effect(current)) end
    local id = withStatusRows(function() return ko.applyRevivePenalty(p, kind, penalty) end)
    local duration = p.added[1] and p.added[1].duration or 0
    local removedWeak = 0
    for _, r in ipairs(p.removed) do if r == ko.WEAKNESS then removedWeak = 1 end end
    return id, duration, #p.added, removedWeak
end

-- Raise on a corpse: HP percent offered, 1 if the offer carries the KO penalty, the text id.
function raiseOffer(enhancedRaise)
    local caster = chara({ class = 23, traits = { [27363] = enhancedRaise } })
    local corpse = chara({ dead = true })
    local a = action()
    load("Command/Magic/Raise").onSkillFinish(caster, corpse, skill({ commandType = CommandType.Spell }), a, container())
    return corpse.log.raiseHp or -1, corpse.log.raiseWeakness and 1 or 0, a.worldMasterTextId or 0
end

function mpCost(level, permille) return formulas.mpCost(level, permille) end

------------------------------------------------------------------------------
-- Statuses
------------------------------------------------------------------------------

-- Damage-taken-down percent a status adds on gain.
function damageTakenDown(script, tier)
    local p = chara()
    load(script).onGain(p, effect(0, { tier = tier }), container())
    return p.mods[M.DamageTakenDown] or 0
end

-- Bloodbath after a command of the given type dealing `damage`: HP drained, 1 if the status ended.
function bloodbath(damage, commandType)
    local s = load("Status/Bloodbath")
    local caster, mob = chara(), chara({ player = false })
    local eff = caster:Give(effect(223061))
    s.onHit(eff, caster, mob, skill({ commandType = commandType }), action({ amount = damage }), container())
    return caster.log.addHp or 0, caster.statusEffects:HasStatusEffect(223061) and 0 or 1
end

-- Blood for Blood on a command of the given type at `hp`: HP taken, 1 if the status ended.
function bloodForBlood(hp, commandType)
    local s = load("Status/BloodForBlood")
    local caster = chara({ hp = hp, maxHp = 3000 })
    local eff = caster:Give(effect(223063))
    s.onPreAction(eff, caster, chara({ player = false }), skill({ commandType = commandType }), action({ amount = 100 }), container())
    return caster.log.delHp or 0, caster.statusEffects:HasStatusEffect(223063) and 0 or 1
end

-- Aegis Boon against a swing of `blocked`: block rate, block reduction, HP restored, 1 if ended.
function aegisBoon(blocked)
    local s = load("Status/AegisBoon")
    local tank, mob = chara(), chara({ player = false })
    local eff = tank:Give(effect(223164))
    local a = action({ amount = blocked, amountMitigated = blocked })
    s.onPreAction(eff, mob, tank, skill(), a, container())
    s.onBlock(eff, mob, tank, skill(), a, container())
    return a.blockRate or 0, a.blockReduction or 0, tank.log.addHp or 0, tank.statusEffects:HasStatusEffect(223164) and 0 or 1
end

-- Stoneskin's absorb magnitude from Enhancing potency.
function stoneskin(potency, enhanced)
    local caster = chara({ class = 23, mods = { [M.EnhancementMagicPotency] = potency }, traits = { [27364] = enhanced } })
    local sk = skill({ commandType = CommandType.Spell })
    load("Command/Magic/Stoneskin").onSkillFinish(caster, caster, sk, action(), container())
    return sk.statusMagnitude
end

-- Presence of Mind on a spell with castMs: cast after, recast after, 1 if the status ended.
function presenceOfMind(castMs)
    local s = load("Status/PresenceOfMind")
    local caster = chara({ class = 23 })
    local eff = caster:Give(effect(223116))
    local sk = skill({ commandType = CommandType.Spell, castTimeMs = castMs, recastTimeMs = 300000 })
    s.onMagicCast(eff, caster, sk)
    s.onCommandFinish(eff, caster, sk, container())
    return sk.castTimeMs, sk.recastTimeMs, caster.statusEffects:HasStatusEffect(223116) and 0 or 1
end

-- Hits per auto-attack with Spinning Heel, from the weapon's own count.
function spinningHeel(baseHits)
    local p = chara({ baseHits = baseHits })
    p.mods[M.HitCount] = baseHits
    load("Status/SpinningHeel").onGain(p, effect(223245), container())
    return p.mods[M.HitCount]
end

-- Featherfoot on an evade: MP gained, 1 if the status ended.
function featherfoot(tier)
    local s = load("Status/Featherfoot")
    local p = chara({ mp = 0, maxMp = 3000 })
    local eff = p:Give(effect(223132, { tier = tier }))
    s.onEvade(eff, chara({ player = false }), p, skill(), action(), container())
    return p.log.addMp or 0, p.statusEffects:HasStatusEffect(223132) and 0 or 1
end

-- Fists stance: the stat it raises (a Modifier name) as a share of before, and the MP one tick takes.
function fists(script, modName, tier, afBody)
    local mod = M[modName]
    local p = chara({ base = { [M.Attack] = 1000, [M.Defense] = 1000 }, mods = { [M.Attack] = 0, [M.Defense] = 0 },
        equipped = afBody and { [8032702] = 10 } or {} })
    local s = load(script)
    local eff = effect(0, { tier = tier })
    s.onGain(p, eff, container())
    local share = p:GetMod(mod) / 1000
    s.onTick(p, eff, container())
    return share, p.log.delMp or 0
end

-- A song's magnitude from its command script.
function songMagnitude(script, level, battleVoice, pie)
    local caster = chara({ class = 24, level = level, mods = pie and { [M.Piety] = pie } or nil })
    if battleVoice then caster:Give(effect(223253)) end
    local sk = skill({ commandType = CommandType.Spell })
    load(script).onMagicStart(caster, caster, sk)
    return sk.statusMagnitude
end

-- What a status adds on gain with `magnitude` to each named modifier.
function statusMods(script, magnitude, aName, bName)
    local a, b = M[aName], bName and M[bName]
    local p = chara({ mods = { [M.Refresh] = 0, [M.Regain] = 0, [M.Regen] = 0, [M.Accuracy] = 0, [M.MagicAccuracy] = 0 } })
    load(script).onGain(p, effect(0, { magnitude = magnitude }), container())
    return p.mods[a] or 0, b and (p.mods[b] or 0) or 0
end

-- Divine Veil's regen on the party after a Cure: magnitude, duration.
function divineRegen(tier)
    local s = load("Status/DivineVeil")
    local pld, whm, ally = chara(), chara({ class = 23 }), chara()
    local eff = pld:Give(effect(223248, { tier = tier }))
    function pld:GetPartyMembersInRange()
        local i = 0
        return function() i = i + 1; return ({ ally })[i] end
    end
    local sk = skill({ commandType = CommandType.Spell, actionType = ActionType.Heal })
    sk.id = 27346
    s.onHealed(eff, whm, pld, sk, action(), container())
    local add = ally.added[1] or {}
    return add.magnitude or 0, add.duration or 0, add.id or 0
end

-- Regen's HP per tick from Enhancing potency.
function regenTick(potency, afBoots)
    local caster = chara({ class = 23, mods = { [M.EnhancementMagicPotency] = potency },
        equipped = afBoots and { [8081806] = 14 } or {} })
    local sk = skill({ commandType = CommandType.Spell })
    load("Command/Magic/Regen").onSkillFinish(caster, caster, sk, action(), container())
    return sk.statusMagnitude
end

-- Invigorate from its ability script: TP per tick and duration, from the row's duration.
function invigorate(enhanced, rowDuration, afBody)
    local caster = chara({ class = 8, traits = { [27280] = enhanced }, equipped = afBody and { [8032704] = 10 } or {} })
    local sk = skill({ commandType = CommandType.Ability, statusDuration = rowDuration })
    load("Command/Ability/Invigorate").onAbilityStart(caster, caster, sk)
    return sk.statusMagnitude, sk.statusDuration
end

function poisonTick(level) return items.poisonTick(level) end

------------------------------------------------------------------------------
-- Status landing
------------------------------------------------------------------------------

-- Landing chance of a pure enfeeble from a caster `extra` points over level-typical potency and
-- magic accuracy, on a level-typical player.
function enfeebleChance(extra, useMacc)
    local exp = stats.expected(23, 50)
    local typical = exp.magic + exp.pie / 4
    local caster = chara({ class = 23, mods = { [M.EnfeeblingMagicPotency] = typical + extra, [M.MagicAccuracy] = typical + extra } })
    local target = chara({ class = 3, mods = { [M.MagicEvasion] = stats.expected(3, 50).magic + stats.expected(3, 50).pie / 4 } })
    return formulas.statusLandChance(caster, target, 223007, 1.0, "enfeeble", useMacc)
end

-- A sleep spell's landing chance (as handed to DoAction) from a listed chance, for extra
-- enfeebling potency and magic accuracy over level-typical.
function sleepChance(script, listed, extraPotency, extraMacc)
    local exp = stats.expected(23, 50)
    local caster = chara({ class = 23, mods = {
        [M.EnfeeblingMagicPotency] = exp.magic + exp.pie / 4 + extraPotency,
        [M.MagicAccuracy] = exp.magic + exp.mnd / 4 + extraMacc } })
    local target = chara({ level = 50, player = false })
    local a = action()
    load(script).onSkillFinish(caster, target,
        skill({ commandType = CommandType.Spell, statusId = 228001, statusChance = listed }), a, container())
    return a.chanceAtAction
end

-- Enfeebling potion thrown `tries` times by a user with every stat at `statLevel`: landings.
function potionLandings(itemId, statLevel, tries)
    local mods = {}
    for id = 1, 200 do mods[id] = statLevel end
    local user = chara({ class = 23, mods = mods })
    local mob = chara({ player = false })
    math.randomseed(1234)
    withStatusRows(function()
        for _ = 1, tries do items.use(user, mob, itemId, container()) end
    end)
    return #mob.added
end

-- Enfeebling potion statuses: count, then id and seconds of the first two.
function enfeeblePotion(itemId)
    local list = items.ENFEEBLE[itemId] or {}
    local a, b = list[1] or { 0, 0 }, list[2] or { 0, 0 }
    return #list, a[1], a[2], b[1], b[2]
end

-- Unguent: status id and duration it applies to the user.
function unguent(itemId)
    local user = chara()
    withStatusRows(function() items.use(user, user, itemId, container()) end)
    local add = user.added[1] or {}
    return add.id or 0, add.duration or 0
end

-- Maddening Potion: enmity added on each of two mobs that hate the user.
function maddening(level)
    local user = chara({ level = level })
    local m1, m2 = chara({ player = false }), chara({ player = false })
    m1:Hates(user, 0)
    m2:Hates(user, 0)
    user.CurrentArea = area({ m1, m2 })
    items.onMedicine(user, items.MADDENING_POTION, container())
    return m1.hate[user.Id], m2.hate[user.Id]
end

------------------------------------------------------------------------------
-- Party bonus
------------------------------------------------------------------------------

-- A party-bonus status script's layers as shares of base: HP, MP, accuracy, magic accuracy.
function partyBonus(script)
    local base = { [M.Hp] = 2000, [M.Mp] = 1000, [M.Accuracy] = 1000, [M.MagicAccuracy] = 1000 }
    local p = chara({ base = base, mods = { [M.Accuracy] = 0, [M.MagicAccuracy] = 0 }, hp = 2000, mp = 1000 })
    load(script).onGain(p, effect(0), container())
    return (p:GetMod(M.Hp) - 2000) / 2000, (p:GetMod(M.Mp) - 1000) / 1000,
        (p:GetMod(M.Accuracy) - 1000) / 1000, (p:GetMod(M.MagicAccuracy) - 1000) / 1000
end

------------------------------------------------------------------------------
-- Recasts
------------------------------------------------------------------------------

-- An ability's recast (ms) after onAbilityStart from the row's `baseMs`.
function abilityRecast(script, baseMs, traitId, itemId, slot)
    local caster = chara({ traits = traitId and traitId > 0 and { [traitId] = true } or {},
        equipped = itemId and itemId > 0 and { [itemId] = slot } or {} })
    local sk = skill({ commandType = CommandType.Ability, recastTimeMs = baseMs })
    load(script).onAbilityStart(caster, chara({ player = false }), sk)
    return sk.recastTimeMs
end

-- Light Shot's recast (ms) with a bow of the given delay.
function lightShotRecast(delay)
    local caster = chara({ class = 7 })
    local sk = skill({ commandType = CommandType.Ability, recastTimeMs = 0 })
    steady(function()
        load("Command/Ability/LightShot").onAbilityStart(caster, chara({ player = false }), sk)
    end, 30, delay)
    return sk.recastTimeMs
end
