require("Modifiers")

--Sanguine Rite restores 30% of damage taken as MP
function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
	local mpToRestore = action.amount * 0.30
	defender:AddMP(mpToRestore)
	actionContainer:AddMPAction(defender.Id, 33011, mpToRestore)
end