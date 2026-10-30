require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Regain, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.Regain, effect:GetMagnitude())
end
