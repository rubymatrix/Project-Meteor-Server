require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.RegenDown, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.RegenDown, effect:GetMagnitude())
end
