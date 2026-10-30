require("Modifiers")

function onGain(owner, effect, actionContainer)
	local speedModifier = 0.8

	owner:MultiplyMod(Modifier.MovementSpeed, speedModifier)
end

function onLose(owner, effect, actionContainer)
	local speedModifier = 0.8

	owner:DivideMod(Modifier.MovementSpeed, speedModifier)
end