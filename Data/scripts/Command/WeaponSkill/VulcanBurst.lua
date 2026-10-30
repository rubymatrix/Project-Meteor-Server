require("Global")
require("Battle/Actions")

--[[
Ifrit's Vulcan Burst: a circle of 16 around him after 2 s readying, knocking targets back. MAGNITUDE
is fitted to retail hits on Lv50 players (about 525 damage per 1000 magnitude from a Lv58 caster).
Shape and radius come from the encounter script and the mob skill seed.
--]]

MAGNITUDE = 1125

-- Retail sends every hit with this effect (physical plate, knockback 5, recoil 2) and text.
-- The knockback bits make the client throw the target back from Ifrit.
KNOCKBACK_EFFECT = 0x08001E35
KNOCKBACK_TEXT = 30301
KNOCKBACK_IMMUNE = 130   -- Modifier.KnockbackImmune

function onSkillPrepare(caster, target, skill)
	return 0
end

function onSkillStart(caster, target, skill)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.attackSpell(caster, target, skill, action, actionContainer, { magnitude = MAGNITUDE })
	-- after DoAction: the result object is what the packet is built from
	if action.amount > 0 and target:GetMod(KNOCKBACK_IMMUNE) <= 0 then
		action.effectId = KNOCKBACK_EFFECT
		action.worldMasterTextId = KNOCKBACK_TEXT
	end
end
