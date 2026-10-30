require("Modifiers")

function onGain(owner, effect, actionContainer)
	--Only one song per bard can be active, need to figure out a good way to do this
	owner:AddMod(Modifier.Accuracy, effect:GetMagnitude())
	owner:AddMod(Modifier.MagicAccuracy, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Accuracy, effect:GetMagnitude())
	owner:SubtractMod(Modifier.MagicAccuracy, effect:GetMagnitude())
end