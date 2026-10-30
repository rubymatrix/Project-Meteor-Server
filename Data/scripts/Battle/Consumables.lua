require("Battle/Statlayers")

--[[
Well Fed (food) and Medicated (medicine) stat buffs. C# (Character.ApplyConsumableBuff) sizes them
from server_items_consumable: min(stat x %, cap) per effect, or a flat value. The status keeps the
item id as its magnitude and owns one stat layer, so re-applying replaces it.
--]]

consumables = consumables or {}

consumables.MEDICATED = 223998
consumables.WELL_FED = 223999
consumables.LAYER_MEDICATED = "status:medicated"
consumables.LAYER_WELL_FED = "status:wellfed"

local function apply(owner, statusId, layer, on)
	if on then
		local effect = owner.statusEffects:GetStatusEffectById(statusId)
		if effect ~= nil then
			owner:ApplyConsumableBuff(layer, effect:GetMagnitude())
			return
		end
	end
	owner:ClearConsumableBuff(layer)
end

function consumables.applyMedicated(owner, on)
	apply(owner, consumables.MEDICATED, consumables.LAYER_MEDICATED, on)
end

function consumables.applyWellFed(owner, on)
	apply(owner, consumables.WELL_FED, consumables.LAYER_WELL_FED, on)
end

-- medicine first: food is sized without it
statlayers.register(consumables.MEDICATED, consumables.applyMedicated)
statlayers.register(consumables.WELL_FED, consumables.applyWellFed)
