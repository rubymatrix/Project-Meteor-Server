require("Global")
local crossclass = require("Battle/Crossclass")

--[[
Equips, moves or unequips a battle command in an action slot, after the cross-class and
learned checks. Current-class actions are placed by the server and can't be removed.
--]]

function onEventStarted(player, equipAbilityWidget, eventType, eventName, slot, commandid, unkown, arg1, arg2, arg3, arg4, arg5, arg6)
	local worldManager = GetWorldManager()
	local ability = worldManager:GetBattleCommand(commandid)

	-- arg5 1 is the gift (Godsend) slots, which aren't implemented.
	if arg5 == 1 then
		player:EndEvent()
		return
	end

	--Equip
	if commandid > 0 then
		if ability == nil then
			--"That action cannot be set to an action slot."
			player:SendGameMessage(GetWorldMaster(), 30723, 0x20, 0, 0)
			player:EndEvent()
			return
		end

		local current = player:GetCurrentClassOrJob()
		local refuse = crossclass.canSet(current, ability)
		if refuse ~= nil then
			player:SendGameMessage(GetWorldMaster(), refuse, 0x20, 0, 0)
			player:EndEvent()
			return
		end
		-- Counted from the bar so a stale otherClassAbilityCount can't block.
		local alreadySet = player:FindFirstCommandSlotById(commandid) < player.charaWork.commandBorder + 30
		if not alreadySet and not crossclass.isOwn(current, ability.job)
			and crossclass.countSet(player, current) >= crossclass.cap(current, player:GetLevel()) then
			--"You cannot set any more actions."
			player:SendGameMessage(GetWorldMaster(), 30720, 0x20, 0, 0)
			player:EndEvent()
			return
		end

		-- Learned on its own class (a job's on its base class), not gated by the current level.
		local learnClass = crossclass.JOB_BASE[ability.job] or ability.job
		if player.charaWork.battleSave.skillLevel[learnClass - 1] < ability.level then
			--"You have not yet acquired that action."
			player:SendGameMessage(GetWorldMaster(), 30742, 0x20, 0, 0)
			player:EndEvent()
			return
		end

		local oldSlot = player:FindFirstCommandSlotById(commandid)
		local isEquipped = oldSlot < player.charaWork.commandBorder + 30
		--If slot is 0, find the first open slot
		if slot == 0 then
			if isEquipped == true then
				--"That action is already set to an action slot."
				player:SendGameMessage(GetWorldMaster(), 30719, 0x20, 0)
				player:EndEvent()
				return
			end

			slot = player:FindFirstCommandSlotById(0) - player.charaWork.commandBorder

			if slot >= 30 then
				--"You cannot set any more actions."
				player:SendGameMessage(GetWorldMaster(), 30720, 0x20, 0)
				player:EndEvent()
				return
			end
		else
			slot = slot - 1
		end

		-- Moves a command already on the bar; a displaced current-class action goes to a free slot.
		player:EquipAbility(current, commandid, slot + player.charaWork.commandBorder, not isEquipped)

	--Unequip (slot is 1-based)
	elseif commandid == 0 then
		local command = player.charaWork.command[slot + player.charaWork.commandBorder - 1]
		if command ~= nil and command ~= 0 and player:IsOwnAction(command) then
			--"Actions of your current class or job cannot be removed."
			player:SendGameMessage(GetWorldMaster(), 30745, 0x20, 0, 0)
		else
			player:UnequipAbility(slot)
		end
	end

	player:EndEvent()
end
