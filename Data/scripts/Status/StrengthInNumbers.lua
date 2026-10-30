require("Modifiers")
require("Battle/Partybonus")

--[[
Strength in Numbers (223194): full party (8 members) bonus with no timer: max HP/MP +10%, physical
accuracy +20%, magic accuracy +10%. Sizes live in Battle/Partybonus.lua. Granted and removed by
Player.UpdatePartyBonus.
--]]

function onGain(owner, effect, actionContainer)
	partybonus.apply(owner, "strengthInNumbers", true)
end

function onLose(owner, effect, actionContainer)
	partybonus.apply(owner, "strengthInNumbers", false)
end
