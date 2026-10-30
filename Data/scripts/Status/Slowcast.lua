require("Modifiers")
require("BattleUtils")

function onMagicCast(effect, caster, skill)
	skill.castTimeMs = skill.castTimeMs * 1.5
end