require("Global")
require("Ability")
require("Battle/Actions")

--[[
Raises the enmity of every action by 1.5x for 15 s, or 1.65x with Fighter's Burgeonet (AF head)
equipped. Battle/Actions.lua enmityScale applies it; tier 2 marks the AF bonus.
--]]

local AF_HEAD, SLOT_HEAD = 8013503, 8     -- Fighter's Burgeonet, head slot

function onAbilityPrepare(caster, target, ability)
	return 0
end

function onAbilityStart(caster, target, ability)
	local ok, has = pcall(function() return caster:HasItemEquippedInSlot(AF_HEAD, SLOT_HEAD) end)
	if ok and has then ability.statusTier = 2 end
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	actions.statusAbility(caster, target, skill, action, actionContainer, {})
end
