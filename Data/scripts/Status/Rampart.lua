require("Modifiers")
require("Battle/Stats")

--[[
Rampart (223064, GLA 27142): defense up for 60 s. It adds one level-typical DEF (Battle/Stats.lua),
which under Battle/Formulas.lua's DEF/(DEF + 3 x level-typical) cuts a level-typical defender's
damage taken by about 20%.
--]]

function onGain(owner, effect, actionContainer)
	local e = stats.expected(stats.classOf(owner), owner:GetLevel())
	effect:SetMagnitude(math.floor(e.def))
	owner:AddMod(Modifier.Defense, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Defense, effect:GetMagnitude())
end
