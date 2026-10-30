require("Battle/Consumables")

--[[
Well Fed (223999): food buff for the item's duration (30:00), magnitude = the food's item id. Each
stat gets min(stat x %, cap) from server_items_consumable; every food also gives +3% EXP
(BattleUtils.AddBattleBonusEXP). See Battle/Consumables.lua.
--]]

function onGain(owner, effect, actionContainer)
	owner:ApplyConsumableBuff(consumables.LAYER_WELL_FED, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:ClearConsumableBuff(consumables.LAYER_WELL_FED)
end
