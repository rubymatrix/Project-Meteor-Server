require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Regen, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Regen, effect:GetMagnitude())
end
