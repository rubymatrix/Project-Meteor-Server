require("Battle/Consumables")

--[[
Medicated (223998): stat medicine (Potion of Strength etc., Maddening Potion, Nerve Drops),
magnitude = the item id. Each stat gets min(stat x %, cap), or a flat Enmity change, from
server_items_consumable. Ends on KO. See Battle/Consumables.lua.
--]]

function onGain(owner, effect, actionContainer)
	owner:ApplyConsumableBuff(consumables.LAYER_MEDICATED, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:ClearConsumableBuff(consumables.LAYER_MEDICATED)
end
