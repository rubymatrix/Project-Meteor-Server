--[[
Taunted (223073, put on the target by Taunt 27102 PGL42), 5 s. The mob AI always attacks the top of
its hate list (BattleNpcController.HandleHate), so the taunter is kept 1 point above the top on gain
and every tick. The padding is taken back at the end, so the mob returns to whoever really holds
hate. Enmity the taunter earns meanwhile stays.
--]]

local function hate(owner)
	local ok, hc = pcall(function() return owner.hateContainer end)
	if ok then return hc end
	return nil
end

local function enmityOf(hc, chara)
	if not hc:HasHateForTarget(chara) then return 0 end
	return hc:GetHateList()[chara].cumulativeEnmity
end

local function holdLock(owner, effect)
	local hc = hate(owner)
	local src = effect:GetSource()
	if hc == nil or src == nil or src == owner or not src:IsAlive() then return end

	local top = hc:GetMostHatedTarget()
	if top == src then return end

	local need = 1
	if top ~= nil then
		need = enmityOf(hc, top) - enmityOf(hc, src) + 1
	end
	if need > 0 then
		hc:UpdateHate(src, need)
		effect:SetExtra(effect:GetExtra() + need)
	end
end

function onGain(owner, effect, actionContainer)
	effect:SetExtra(0)
	holdLock(owner, effect)
end

function onTick(owner, effect, actionContainer)
	holdLock(owner, effect)
end

function onLose(owner, effect, actionContainer)
	local hc = hate(owner)
	local src = effect:GetSource()
	local added = effect:GetExtra()
	if hc == nil or src == nil or added <= 0 or not hc:HasHateForTarget(src) then return end

	--never take the entry below 1 (UpdateHate adds as uint)
	local take = math.min(added, enmityOf(hc, src) - 1)
	if take > 0 then
		hc:UpdateHate(src, -take)
	end
end
