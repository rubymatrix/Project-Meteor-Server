require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.KnockbackImmune, 1)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.KnockbackImmune, 1)
end