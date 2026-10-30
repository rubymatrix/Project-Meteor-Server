require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Fire damage to enemies around the caster, falling off from x1.0 at the caster to x0.5 at 8 y.
Can add the Flare DoT (Status/Flare2.lua) at 20 per tick.
--]]

local FALLOFF_RANGE = 8     -- the DB AoE radius

local params = {
	magnitude = 2000,
	stats = { [Modifier.Intelligence] = 1.5 },
	status = "always",
	scale = function(caster, target, skill, combo)
		local ok, d = pcall(function()
			local dx, dz = caster.positionX - target.positionX, caster.positionZ - target.positionZ
			return math.sqrt(dx * dx + dz * dz)
		end)
		if not ok or d == nil then return 1.0 end
		return 1.0 - 0.5 * math.min(d, FALLOFF_RANGE) / FALLOFF_RANGE
	end,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	skill.statusMagnitude = 20
	actions.attackSpell(caster, target, skill, action, actionContainer, params)
end
