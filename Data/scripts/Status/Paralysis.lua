--[[
Paralysis (223005). Each action the owner tries has a 25% chance to fail. The AI states do this in
C# (Character.RollParalysis, PARALYSIS_FAIL_PERCENT). The status row's ActivateOnPreactionCaster
flag needs an onPreAction, so it stays as a no-op.
--]]

function onPreAction(effect, caster, target, skill, action, actionContainer)
end
