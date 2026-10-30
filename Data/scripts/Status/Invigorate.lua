require("Modifiers")

--100 TP per tick without AF. 133 TP per tick with AF
function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Regain, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Regain, effect:GetMagnitude())
end
