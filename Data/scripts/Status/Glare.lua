require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Accuracy, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.Accuracy, effect:GetMagnitude())
end