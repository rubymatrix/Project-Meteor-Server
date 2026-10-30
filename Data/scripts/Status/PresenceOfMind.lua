require("Modifiers")
require("BattleUtils")

--[[
Presence of Mind (223116, from ability 27344 WHM30): the next spell of any kind has cast and recast
time 0. It is consumed when that cast completes, so a cast that fails before starting keeps it.
--]]

--skill is a per-cast clone (WorldManager.GetBattleCommand), so this only touches this cast.
--Runs before the cast bar is sent, so the client sees an instant cast; recast 0 means
--DoBattleCommand starts no hotbar timer for the spell.
function onMagicCast(effect, caster, skill)
	if skill:GetCommandType() == CommandType.Spell then
		skill.castTimeMs = 0
		skill.recastTimeMs = 0
	end
end

function onCommandFinish(effect, owner, skill, actionContainer)
	if skill:GetCommandType() == CommandType.Spell then
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
