require("Modifiers")

--Set magnitude to milliseconds that HF will reduce delay by
function onGain(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Delay, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.Delay, effect:GetMagnitude())
end