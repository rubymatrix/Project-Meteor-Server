require("Modifiers")
require("BattleUtils")

--Forces crit of a single WS action from rear.
function onPreAction(effect, caster, target, skill, action, actionContainer)
	--Only the next weaponskill uses it up; auto-attacks and other commands leave it alone.
	--The status lives on the caster (ActivateOnPreactionCaster), so remove it from there.
	if skill:GetCommandType() ~= CommandType.Weaponskill then
		return
	end

	if action.param == HitDirection.Rear then
		--Set action's crit rate to 100%
		action.critRate = 100.0
	end

	--Figure out INT bonus for tier 2

	--Remove status and add message
	caster.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
end

