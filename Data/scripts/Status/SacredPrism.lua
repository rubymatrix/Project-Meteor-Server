require("Modifiers")
require("BattleUtils")

--[[
Sacred Prism (223225, from ability 27340): 60 s or until the next eligible spell. That spell takes
x1.5 cast time and hits an 8-yalm circle around its target, the radius of Protect and Curaga.
The status ends when the cast completes, so a cancelled cast keeps it.
--]]

local CAST_MULT = 1.5
local AOE_RADIUS = 8

local SUPPORTED = {
	[27346] = true, -- Cure
	[27347] = true, -- Cura
	[27358] = true, -- Regen
	[27357] = true, -- Esuna
	[27350] = true, -- Stoneskin
	[27307] = true, -- Sanguine Rite
}

function onMagicCast(effect, caster, skill)
	if SUPPORTED[skill.id] then
		skill.castTimeMs = math.floor(skill.castTimeMs * CAST_MULT)
		skill.aoeType = TargetFindAOEType.Circle
		skill.aoeRange = AOE_RADIUS
	end
end

function onCommandFinish(effect, owner, skill, actionContainer)
	if SUPPORTED[skill.id] then
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
