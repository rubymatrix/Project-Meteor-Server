require("Modifiers")

function onGain(owner, effect, actionContainer)
end

function onLose(owner, effect, actionContainer)
end

function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
	defender.statusEffects:RemoveStatusEffect(effect, actionContainer)
end