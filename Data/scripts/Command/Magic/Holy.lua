require("Global")
require("Modifiers")
require("Battle/Actions")

--[[
Consumes all MP to deal damage around the caster, with a chance to Bind. Damage is x(1 + 1.5 x
MP fraction), x2.5 at full MP. Every target sees the pre-cast MP, so the drain waits for the last
target; C# then deducts the listed cost after onSkillFinish, ending the cast at 0 MP.
--]]

local params = {
	magnitude = 2000,
	stats = { [Modifier.Intelligence] = 1.0, [Modifier.Mind] = 1.0 },
	status = "always",
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	local frac = caster:GetMP() / math.max(1, caster:GetMaxMP())
	params.scale = function() return 1 + 1.5 * frac end
	actions.attackSpell(caster, target, skill, action, actionContainer, params)

	local targets = actions.commandTargets(skill)
	local last = targets[#targets]
	if last == nil or last.Id == target.Id then
		local extra = caster:GetMP() - skill:CalculateMpCost(caster)
		if extra > 0 then caster:DelMP(extra) end
	end
end
