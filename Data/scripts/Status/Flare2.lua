require("Modifiers")

--[[

Flare DoT

Flare's damage over time. The tick is the status magnitude (Command/Magic/Flare.lua sets it),
dealt every 3 s through the RegenDown mod. Needs status row 223262 with debuff flags 21, like Aero.

--]]

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.RegenDown, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.RegenDown, effect:GetMagnitude())
end
