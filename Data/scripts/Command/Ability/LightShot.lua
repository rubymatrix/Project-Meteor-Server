require("Global")
require("Ability")
require("Battle/Actions")
require("Battle/Stats")

--[[
The archer's ranged attack, keyed to the bow's base Damage like an auto-attack. Its recast is the
bow's delay (the DB row keeps recast 0). Under Barrage it fires once per hit at -10 accuracy, and
a volley splits one auto-attack round of TP across its hits.
--]]

local params = {
	potency = 1.0,
}
local BARRAGE_ACC = -10

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	local delay = stats.weapon(caster).delay
	if delay ~= nil and delay > 0 then
		ability.recastTimeMs = math.floor(delay * 1000)
		ability.maxRecastTimeSeconds = math.ceil(delay)
	end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	--For some reason, light shot's hitNum is always 1 (or 0, idk), even with barrage.
	--If you set the hitnum like any other multi-hit WS it will play the animation repeatedly.
	action.hitNum = 1

	local p = { potency = params.potency }
	if skill.numHits > 1 then
		p.acc = BARRAGE_ACC
	end
	actions.rangedShot(caster, target, skill, action, actionContainer, p)

	-- An ability gets no TP from the auto-attack path, so the shot grants it here.
	if action:ActionLanded() then
		local delay = stats.weapon(caster).delay or 0
		local storeTp = 1 + caster:GetMod(Modifier.StoreTp) * 0.001
		local round = math.floor(delay * 100 * storeTp + 0.5)
		local hits = math.max(1, skill.numHits or 1)
		caster:AddTP(math.floor(round / hits + 0.5))
	end
end
