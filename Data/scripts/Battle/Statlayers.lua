require("Modifiers")

--[[
Statuses that change a stat by a percentage (Weakness, Comradery, ...) each own a stat layer,
sized from the character's base value so re-applying never compounds. Base HP/MP is 0 until
onCalculateBaseStats runs (a status loaded at login), so the layer stays 0 until statlayers.refresh
re-applies it.
--]]

statlayers = statlayers or {}

local M = Modifier

local function isPool(mod)
	return mod == M.Hp or mod == M.Mp
end

function statlayers.set(owner, layer, mod, pct)
	owner:SetStatLayer(layer, mod, 0)
	if pct == 0 then return end

	local base = owner:GetBaseStat(mod)
	if base <= 0 and not isPool(mod) then base = owner:GetMod(mod) end
	if base <= 0 then return end

	owner:SetStatLayer(layer, mod, math.floor(math.abs(base * pct)) * (pct < 0 and -1 or 1))
end

-- Only for characters whose HP/MP come from the base layer.
function statlayers.syncPools(owner)
	if owner:GetBaseStat(M.Hp) > 0 then
		owner:SetMaxHP(math.max(1, math.floor(owner:GetMod(M.Hp))))
		if owner:GetHP() > owner:GetMaxHP() then owner:SetHP(owner:GetMaxHP()) end
	end
	if owner:GetBaseStat(M.Mp) > 0 then
		owner:SetMaxMP(math.max(0, math.floor(owner:GetMod(M.Mp))))
		if owner:GetMP() > owner:GetMaxMP() then owner:SetMP(owner:GetMaxMP()) end
	end
end

statlayers.refreshers = statlayers.refreshers or {}

function statlayers.register(statusId, apply)
	statlayers.refreshers[statusId] = apply
end

-- Also turns off layers of statuses lost without their onLose.
function statlayers.refresh(owner)
	for id, apply in pairs(statlayers.refreshers) do
		apply(owner, owner.statusEffects:HasStatusEffect(id), true)
	end
end
