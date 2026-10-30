require("Global")

local DREAM_ITEM = {
	{[1] = 3010419, [2] = 3010420, [3] = 3010421}, -- Mizzenmast/Roost/Hourglass Biscuit
	3010003, -- Boiled Egg
	3010101, -- Grilled Carp
	3010001, -- Meat Miq'abob
	3010402, -- Ginger Cookie
	3020001, -- Potion
	3020101, -- Ether
	1000003, -- 5x Crystal Shards (Fire)
	1000004, -- 5x Crystal Shards (Ice)
	1000005, -- 5x Crystal Shards (Wind)
	1000006, -- 5x Crystal Shards (Earth)
	1000007, -- 5x Crystal Shards (Lightning)
	1000008  -- 5x Crystal Shards (Water)
}

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local choice = callClientFunction(player, "askLogout", player)

	-- Quit
	if choice == 2 then
		player:SetSleeping()
		player:QuitGame()
	-- Logout
	elseif choice == 3 then
		player:SetSleeping()
		player:Logout()
	-- Heck the bed
	elseif choice == 4 then
		-- Give items based on dream
		local dreamCode = player:GetLoginDreamCode()
		if dreamCode >= 21 and dreamCode <= 33 then
			local innCode = player:GetHomePointInn()
			local itemCode = DREAM_ITEM[dreamCode - 20]

			-- Get biscuit for inn
			if dreamCode == 21 then
				itemCode = itemCode[innCode]
			end

			-- If crystals you get x5 otherwise x1.
			if dreamCode >= 28 and dreamCode <= 33 then
				player:AddItem(itemCode, 5)
			else
				player:AddItem(itemCode, 1)
			end

			-- Clear the code so they player doesn't keep getting things
			player:SetLoginDreamCode(0)
		else
			-- Otherwise show standard message
			player:SendGameMessage(player, npc, 7, 0x20)
		end
	end

	player:EndEvent()
end