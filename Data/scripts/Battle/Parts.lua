require("Modifiers")

--[[
Monster body parts. Part-targeting weaponskills add their damage to the part's counter; at
BREAK_SHARE of max HP the part is incapacitated for 30 s and the counter restarts. While broken,
TP moves needing the part are unusable (PartBreak.cs), and a part broken once unlocks its drops.
--]]

parts = parts or {}

parts.BODY = 1
parts.RIGHT_ARM = 2
parts.LEFT_ARM = 3
parts.LEGS = 4
parts.HEAD = 5
parts.SPECIAL_RIGHT = 6
parts.SPECIAL_LEFT = 7
parts.SPECIAL_REAR = 8
parts.STATUS_BASE = 223019          -- + part
parts.DURATION = 30
parts.BREAK_SHARE = 0.25
parts.MOD_DAMAGE1 = 61              -- MobModifier.PartDamage1 (+ part - 1)
parts.MOD_BROKEN_MASK = 69          -- MobModifier.PartsBrokenMask

parts.WS_PART = {
	[27111] = 5, [27115] = 4,                   -- PGL Concussive Blow (head), Demolish (legs)
	[27152] = 2, [27151] = 6,                   -- GLA Savage Blade (R.arm), Flat Blade (special R)
	[27191] = 5, [27196] = 2, [27195] = 6, [27194] = 8,  -- MRD Skull Sunder, Path of the Storm, Godsbane, Maim
	[27235] = 5, [27229] = 4, [27234] = 7,      -- ARC Bloodletter, Leaden Arrow, Gloom Arrow
	[27273] = 3, [27275] = 7,                   -- LNC Heavy Thrust (L.arm), Impulse Drive (special L)
	[27159] = 5, [27118] = 8,                   -- PLD Spirits Within (head), MNK Dragon Kick (rear)
}

-- Parts 1-8: body, right arm, left arm, legs, head, special right, special left, special rear.
-- names maps a part to the family's own client part name, where the client has one.
local QUAD   = { parts = { 1, 4, 5 } }                                  -- four-legged, no usable arms
local HORNED = { parts = { 1, 4, 5 }, names = { [5] = 42 } }            -- head = "horns"
local BIPED  = { parts = { 1, 2, 3, 4, 5 } }
local WINGED = { parts = { 1, 4, 5, 6, 7 }, names = { [6] = 61, [7] = 74 } }
local TAILED = { parts = { 1, 4, 5, 8 }, names = { [8] = 84 } }
local BLOB   = { parts = { 1 } }
parts.FAMILY = {
	[1] = HORNED, [2] = HORNED, [7] = HORNED, [8] = HORNED,            -- aldgoat, antelope, sheep, buffalo
	[3] = QUAD, [9] = QUAD, [10] = QUAD, [11] = QUAD, [12] = QUAD,       -- wolf, boar, mice, mole, rodent
	[4] = BIPED, [6] = BIPED, [60] = BIPED, [49] = BIPED, [1003] = BIPED, -- opo-opo, goobbue, ogre, coblyn, fomor
	[5] = { parts = { 1, 4, 5, 6, 7 }, names = { [6] = 60, [7] = 73 } }, -- coeurl: whiskers
	[13] = BIPED, [14] = { parts = { 1, 5 } }, [15] = { parts = { 1, 5 }, names = { [5] = 45 } },
	[16] = { parts = { 1, 5, 6, 7 }, names = { [5] = 45, [6] = 57, [7] = 70 } },  -- morbol: maw, vines
	[17] = { parts = { 1, 5 } }, [18] = { parts = { 1, 4, 5 } }, [19] = TAILED,
	[20] = BLOB, [21] = BLOB, [62] = BLOB, [63] = BLOB, [64] = BLOB, [65] = BLOB,
	[22] = { parts = { 1, 2, 3, 4, 8 }, names = { [2] = 20, [3] = 27, [8] = 82 } },    -- crab: claws, shell
	[23] = BIPED, [24] = BIPED, [25] = BIPED, [26] = BIPED, [27] = BIPED, [28] = BIPED, [29] = BIPED,
	[30] = TAILED, [31] = TAILED, [32] = TAILED, [1001] = TAILED,       -- drake, basilisk, raptor, angler
	[33] = { parts = { 1, 4, 5, 8 }, names = { [5] = 46, [8] = 86 } }, -- ant: mandibles, abdomen
	[34] = BLOB, [37] = BLOB, [1002] = BLOB,
	[35] = { parts = { 1, 4, 5, 8 }, names = { [8] = 83 } },           -- diremite: stinger
	[36] = { parts = { 1, 4, 5 } }, [38] = { parts = { 1, 4, 5, 8 }, names = { [8] = 82 } },
	[39] = { parts = { 1, 4, 5 } },
	[40] = WINGED, [41] = WINGED, [42] = WINGED, [43] = WINGED, [44] = WINGED, [45] = WINGED,
	[46] = BLOB, [47] = BIPED, [48] = BIPED, [50] = BIPED,
	[51] = { parts = { 1, 5, 6, 7 }, names = { [5] = 43, [6] = 61, [7] = 74 } },       -- ahriman: eye, wings
	[52] = WINGED, [53] = BLOB, [61] = BLOB,
	[54] = BLOB, [55] = BLOB, [56] = BLOB, [57] = BLOB, [58] = BLOB, [59] = BLOB, [1007] = BLOB,
	[1004] = { parts = { 1, 2, 3, 4, 5 }, names = { [2] = 88, [3] = 89, [4] = 35 } },  -- treant: branches, roots
	[1005] = BLOB, [1006] = BLOB,
}
local DEFAULT_FAMILY = { parts = { 1, 2, 3, 4, 5 } }

function parts.family(mob)
	local g = 0
	pcall(function() g = mob.genusId end)
	return parts.FAMILY[g] or DEFAULT_FAMILY
end

function parts.has(mob, part)
	for _, p in ipairs(parts.family(mob).parts) do
		if p == part then return true end
	end
	return false
end

-- Part name id for messages: the family's own name, else the generic 1-5.
function parts.nameId(mob, part)
	local n = parts.family(mob).names
	if n ~= nil and n[part] ~= nil then return n[part] end
	return part <= 5 and part or 1
end

-- What a monster's base-class init(npc) returns: gameParameter, ?, numBattleCommon (10), aggro,
-- partsName, partsExists[1..8], numEventCommon.
function parts.initParams(npc)
	local e = {}
	for i = 1, 8 do e[i] = false end
	if npc ~= nil then
		for _, p in ipairs(parts.family(npc).parts) do e[p] = true end
	else
		e[1] = true
	end
	return true, true, 10, 0, 1, e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], 0
end

local function bitOf(part) return 2 ^ (8 - part) end           -- breakage byte: part 1 = bit 7

-- Breakage is sub-state byte 0.
function parts.setBreakage(mob, part, on)
	local ss = mob:GetSubState()
	local b = ss.breakage
	local bit = bitOf(part)
	local isSet = math.floor(b / bit) % 2 == 1
	if on and not isSet then ss.breakage = b + bit
	elseif not on and isSet then ss.breakage = b - bit
	else return end
	mob:SubstateModified()
end

-- Called after a weaponskill hit lands (actions.physicalWeaponskill).
function parts.onWeaponskillHit(caster, target, skill, dmg)
	local part = parts.WS_PART[skill.id]
	if part == nil or dmg == nil or dmg <= 0 then return end
	local ok, mob = pcall(function() return target:IsMonster() end)
	if not ok or not mob or not target:IsAlive() or not parts.has(target, part) then return end
	local statusId = parts.STATUS_BASE + part
	if target.statusEffects:HasStatusEffect(statusId) then return end

	local mod = parts.MOD_DAMAGE1 + part - 1
	local total = target:GetMobMod(mod) + dmg
	if total < parts.BREAK_SHARE * target:GetMaxHP() then
		target:SetMobMod(mod, total)
		return
	end
	target:SetMobMod(mod, 0)
	local mask = target:GetMobMod(parts.MOD_BROKEN_MASK)
	local bit = 2 ^ (part - 1)
	if math.floor(mask / bit) % 2 == 0 then target:SetMobMod(parts.MOD_BROKEN_MASK, mask + bit) end
	target.statusEffects:AddStatusEffect(statusId, 1, part, parts.DURATION, 0)
end

-- Shared onGain/onLose for the Status/Incapacitation*.lua scripts.
function parts.onGain(owner, effect)
	parts.setBreakage(owner, effect:GetStatusEffectId() - parts.STATUS_BASE, true)
end

function parts.onLose(owner, effect)
	parts.setBreakage(owner, effect:GetStatusEffectId() - parts.STATUS_BASE, false)
end

return parts
