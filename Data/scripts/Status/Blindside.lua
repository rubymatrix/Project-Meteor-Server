require("Modifiers")
require("BattleUtils")

--[[
Forces a crit on the next weaponskill when it lands from the rear.
--]]

function onPreAction(effect, caster, target, skill, action, actionContainer)
	--Only the next weaponskill uses it up; auto-attacks and other commands leave it alone.
	--The status lives on the caster (ActivateOnPreactionCaster), so remove it from there.
	if skill:GetCommandType() ~= CommandType.Weaponskill then
		return
	end

	if action.param == HitDirection.Rear then
		action.critRate = 100.0
	end

	caster.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
end

