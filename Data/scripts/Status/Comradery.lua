require("Modifiers")
require("Battle/Partybonus")

--[[

Comradery

Light party (4 to 7 members): max HP/MP +5%, physical accuracy +10%, magic accuracy +5%, no
timer. Sizes are in Battle/Partybonus.lua. Player.UpdatePartyBonus grants and removes it.

--]]

function onGain(owner, effect, actionContainer)
	partybonus.apply(owner, "comradery", true)
end

function onLose(owner, effect, actionContainer)
	partybonus.apply(owner, "comradery", false)
end
