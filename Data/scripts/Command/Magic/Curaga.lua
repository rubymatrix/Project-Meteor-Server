require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Heals party members near the target from one pool, lowest HP% first, at most half the pool each.
Scripts run once per target and C# heals as it goes, so the first call solves the common HP%
level from everyone's pre-cast HP. It stores the pool, level and crit in this cast's unused status
fields (statusDuration, statusMagnitude, statusTier) for the later targets.
--]]

local MAGNITUDE = 4000

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

local function share(t, level, cap)
	local maxHp = t:GetMaxHP()
	if maxHp <= 0 then return 0 end
	local missing = maxHp - t:GetHP()
	local want = maxHp * level - t:GetHP()
	return math.max(0, math.min(cap, missing, want))
end

local function solveLevel(targets, pool)
	local cap = pool / 2
	local lo, hi = 0.0, 1.0
	local total = 0
	for _, t in ipairs(targets) do total = total + share(t, 1.0, cap) end
	if total <= pool then return 1.0 end
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		local sum = 0
		for _, t in ipairs(targets) do sum = sum + share(t, mid, cap) end
		if sum > pool then hi = mid else lo = mid end
	end
	return lo
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	if skill.statusDuration == 0 then
		local crit = formulas.healCrit(caster)
		local pool = formulas.healAmount(caster, target, MAGNITUDE) * crit
		if actions.hasStatus(caster, 223227) then pool = pool * 0.8 end     -- Cleric Stance
		pool = math.max(1, math.floor(pool))
		local targets = actions.commandTargets(skill)
		if #targets == 0 then targets = { target } end
		skill.statusDuration = pool
		skill.statusMagnitude = solveLevel(targets, pool)
		skill.statusTier = (crit > 1) and 2 or 1
	end
	local pool = skill.statusDuration
	local amount = math.floor(share(target, skill.statusMagnitude, pool / 2))
	actions.healSpell(caster, target, skill, action, actionContainer, { amount = amount, crit = skill.statusTier == 2 })
end
