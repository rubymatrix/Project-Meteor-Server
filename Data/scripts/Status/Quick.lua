require("Modifiers")

function onGain(owner, effect, actionContainer)
	local speedModifier = 1.25

	owner:MultiplyMod(Modifier.MovementSpeed, speedModifier)
end

function onLose(owner, effect, actionContainer)
	local speedModifier = 1.25

	owner:DivideMod(Modifier.MovementSpeed, speedModifier)
end