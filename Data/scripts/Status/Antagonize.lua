require("Modifiers")

--[[

Antagonize

Enmity x1.5, x1.65 with the AF head (tier 2). Battle/Actions.lua enmityScale applies it to every
action it scores. onCommandStart is empty: it exists so the ActivateOnCommandStart flag on the
status row has a function to call.

--]]

function onCommandStart(effect, owner, skill, actionContainer)
end
