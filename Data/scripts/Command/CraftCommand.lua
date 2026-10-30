require("Global")

--[[
Crafting through the client's CraftJudge widget: recipe pick, synthesis, local leves, repair.
CraftJudge functions, class skills and leve sheet notes: Data/Docs/Scripts/Command/CraftCommand.md.
--]]

local closeCraftStartWidget

local getCraftQuest, isCraftQuest, isLocalLeve, startCrafting

local skillAnim = {
	[22553] = 0x10002000;
	[22554] = 0x10001000;
	[22555] = 0x10003000;
	[29531] = 0x10009002;
}

local craftStartWidgetOpen = false

-- Recipe lists and a recipe's materials are C# objects (indexed from 0). The client calls below
-- take plain values, so copy what they need into Lua tables.
local function recipesToItemIds(recipes)
	local ids = {}
	if recipes ~= nil then
		for i = 0, math.min(recipes.Count, 8) - 1 do
			ids[#ids + 1] = recipes[i].resultItemID
		end
	end
	return ids
end

local function recipeToMatIds(recipe)
	local ids = {}
	for i = 0, 7 do
		ids[i + 1] = recipe.materials[i]
	end
	return ids
end

function onEventStarted(player, commandactor, eventType, eventName, arg1, arg2, arg3, arg4, checkedActorId)
	local currentlyCrafting
	local chosenRecipe
	local MENU_CANCEL, MENU_MAINHAND, MENU_OFFHAND, MENU_REQUEST = 0, 1, 2, 3
	local MENU_RECENT, MENU_AWARDED, MENU_RECENT_DETAILED, MENU_AWARDED_DETAILED = 7, 8, 9, 10

	local debugMessage = true

	local isRecipeRecentSent = false
	local isRecipeAwardSent = false

	local craftJudge = GetStaticActor("CraftJudge")
	local recipeResolver = GetRecipeResolver()

	local operationResult
	local operationMode = -1
	local recipeMode = -1
	local chosenMaterials

	local facilityId = 0
	local isRequestedItemsMode = false  -- False = The default state.  True = User picked a quest recipe/local leve
	local recentRecipes
	local awardedRecipes

	local currentCraftQuest = nil  -- Use this to store any chosen craft quest
	local currentCraftQuestGuildleve = nil  -- Use this to store any chosen local leve

	callClientFunction(player, "delegateCommand", craftJudge, "loadTextData", commandactor)

	player:ChangeState(30)

	while operationMode ~= 0 do
		local prepedMaterials = {0,0,0,0,0,0,0,0}
		if isRequestedItemsMode == true then
			-- Only local leves come with their materials, and those aren't offered yet (see getCraftQuest).
		elseif (operationMode == MENU_RECENT or operationMode == MENU_AWARDED) and recipeMode ~= 0 then
			if operationMode == MENU_RECENT then
				prepedMaterials = recipeToMatIds(recentRecipes[recipeMode-1])
			else
				prepedMaterials = recipeToMatIds(awardedRecipes[recipeMode-1])
			end
		end

		local facilityIdParam = facilityId
		if (operationMode == MENU_RECENT or operationMode == MENU_AWARDED) and recipeMode ~= 0 then
			facilityIdParam = -2
		elseif craftStartWidgetOpen == true then
			craftStartWidgetOpen = true
			facilityIdParam = -1
		end

		operationResult = {callClientFunction(player, "delegateCommand", craftJudge, "start", commandactor, facilityIdParam, isRequestedItemsMode, unpack(prepedMaterials))}
		operationMode = operationResult[1]
		recipeMode = operationResult[2]

		if debugMessage then player:SendMessage(0x20, "", "[DEBUG] Menu ID: " .. tostring(operationMode) .. ", RecipeMode : " .. recipeMode) end

		if operationMode == MENU_CANCEL then
			closeCraftStartWidget(player, craftJudge, commandactor)
		elseif operationMode == MENU_MAINHAND or operationMode == MENU_OFFHAND then
			while true do
				local materials = {}

				-- Handle the possible args returned: Either 0 player items, 1 player item, 2+ palyer items. The rest is always the remaining prepped items.
				if type(operationResult[3]) == "number" then
					materials = {unpack(operationResult, 3)}
				elseif type(operationResult[3]) ~= "number" then
					for i=1,8 do
						if i - 1 <  operationResult[3].numItems then
							materials[i] = player:GetItemPackage(operationResult[3].itemPackages[i-1]):GetItemAtSlot(operationResult[3].itemSlots[i-1]).itemId
							player:SendMessage(0x20, "", "[DEBUG] " .. tostring(materials[i]))
						else
							materials[i] = operationResult[3 + (i - operationResult[3].numItems)]
							player:SendMessage(0x20, "", "[DEBUG] " .. tostring(materials[i]))
						end
					end
				end

				local recipes = recipeResolver:GetRecipeFromMats(unpack(materials))
				local itemIds = recipesToItemIds(recipes)

				if #itemIds == 0 then
					player:SendGameMessage(GetWorldMaster(), 40201, 0x20) -- You cannot synthesize with those materials.
					break
				end

				local chosenRecipeIndex = callClientFunction(player, "delegateCommand", craftJudge, "selectRcp", commandactor, unpack(itemIds))

				if chosenRecipeIndex <= 0 then break end

				chosenRecipe = recipes[chosenRecipeIndex-1]

				if chosenRecipe ~= nil then
					local recipeConfirmed = callClientFunction(player, "delegateCommand", craftJudge, "confirmRcp", commandactor,
						chosenRecipe.resultItemID,
						chosenRecipe.resultQuantity,
						chosenRecipe.crystalId1,
						chosenRecipe.crystalQuantity1,
						chosenRecipe.crystalId2,
						chosenRecipe.crystalQuantity2,
						0,
						0)

					if recipeConfirmed then
						closeCraftStartWidget(player, craftJudge, commandactor)
						isRecipeRecentSent = false
						isRecipeAwardSent = false

						currentlyCrafting = startCrafting(player, commandactor, craftJudge, operationMode, chosenRecipe, currentCraftQuestGuildleve, 80, 100, 50)

						isRequestedItemsMode = false
						currentCraftQuestGuildleve = nil
						currentCraftQuest = nil

						break
					end
				end
			end
		elseif operationMode == MENU_REQUEST then -- Conditional button label based on isRequestedItemsMode
			closeCraftStartWidget(player, craftJudge, commandactor)

			if isRequestedItemsMode == false then    -- "Request Items" hit, close Start and open up the Quest select
				isRecipeRecentSent = false
				isRecipeAwardSent = false

				local quest = getCraftQuest(player, craftJudge, commandactor)
				if quest ~= nil then
					isRequestedItemsMode = true
					currentCraftQuest = quest
				end
			elseif isRequestedItemsMode == true then -- "Normal Synthesis" button hit
				isRequestedItemsMode = false
				currentCraftQuestGuildleve = nil
				currentCraftQuest = nil
			end
		elseif operationMode == MENU_RECENT then -- "Recipes" button hit
			if isRecipeRecentSent == false then
				recentRecipes = player:GetRecentRecipes()
				local itemIds = recipesToItemIds(recentRecipes)
				callClientFunction(player, "delegateCommand", craftJudge, "selectRcp", commandactor, unpack(itemIds)) -- Load up recipe list
				isRecipeRecentSent = true
			end
		elseif operationMode == MENU_AWARDED then -- "Awarded Recipes" tab hit
			if isRecipeAwardSent == false then
				awardedRecipes = player:GetAwardedRecipes()
				local itemIds = recipesToItemIds(awardedRecipes)
				callClientFunction(player, "delegateCommand", craftJudge, "selectRcp", commandactor, unpack(itemIds)) -- Load up Award list
				isRecipeAwardSent = true
			end
		elseif (operationMode == MENU_RECENT_DETAILED or operationMode == MENU_AWARDED_DETAILED) and recipeMode > 0 then -- Pop-up for an item's stats/craft mats on a recent recipe
			local chosenRecipe = operationMode == MENU_RECENT_DETAILED and recentRecipes[recipeMode-1] or awardedRecipes[recipeMode-1]
			local recipeConfirmed = callClientFunction(player, "delegateCommand", craftJudge, "confirmRcp", commandactor,
				chosenRecipe.resultItemID,
				chosenRecipe.resultQuantity,
				chosenRecipe.crystalId1,
				chosenRecipe.crystalQuantity1,
				chosenRecipe.crystalId2,
				chosenRecipe.crystalQuantity2,
				0,
				0)

			-- This should never call? The window with this button only appears when you select a recent recipe with not enough materials. Otherwise it just auto-fills your "table".
			if recipeConfirmed then
				closeCraftStartWidget(player, craftJudge, commandactor)
				isRecipeRecentSent = false
				isRecipeAwardSent = false
				currentlyCrafting = startCrafting(player, commandactor, craftJudge, operationMode, chosenRecipe, currentCraftQuestGuildleve, 80, 100, 50)
			end
		else
			break
		end
	end

	player:ResetMusic()
	player:ChangeState(0)
	player:EndEvent()
end

-- The quest pickers are separate widgets from the Start widget.
function getCraftQuest(player, craftJudge, commandactor)
	local questId = nil

	while true do
		local questCommandId = callClientFunction(player, "delegateCommand", craftJudge, "selectCraftQuest", commandactor)

		if questCommandId then
			questId = questCommandId - 0xA0F00000

			if isCraftQuest(questId) then
				local quest = player:GetQuest(questId)
				local confirm = callClientFunction(player, "delegateCommand", craftJudge, "cfmQst", commandactor, quest:GetQuestId(), 20, 1, 1, 1, 0, 0, "<Path Companion>")
				if confirm == true then
					player:SendGameMessage(craftJudge, 21, 0x20)
					return quest
				end
			-- Local leve crafting needs the leve's materials, recipe and crafted count on the server
			-- (client functions confirmLeve and askContinueLocalleve), which don't exist yet.
			elseif isLocalLeve(questId) then
				player:SendGameMessage(GetWorldMaster(), 40209, 0x20) -- You cannot undertake that endeavor.
			else
				-- Retail's answer to a non-craft quest is unknown.
			   player:SendGameMessage(GetWorldMaster(), 40209, 0x20) -- You cannot undertake that endeavor.
			end
		else
			return nil
		end
	end
end

local function isScenarioQuest(id)
	if id >= 110001 and id <= 120026 then
		return true
	else
		return false
	end
end


function isCraftQuest(id)
	if id >= 110300 and id <= 110505 then
		return true
	else
		return false
	end
end


function isLocalLeve(id)
	if id >= 120001 and id <= 120452 then
		return true
	else
		return false
	end
end

function closeCraftStartWidget(player, craftJudge, commandactor)
	callClientFunction(player, "delegateCommand", craftJudge, "closeCraftStartWidget", commandactor)
	craftStartWidgetOpen = false
end

-- Placeholder synthesis: random progress, just enough to see the minigame run.
function startCrafting(player, commandactor, craftJudge, hand, recipe, quest, startDur, startQly, startHq)
	local choice

	local worldMaster = GetWorldMaster()
	local progress = 0
	local attempts = 5
	local craftedCount = 0
	local craftTotal = 2

	player:ChangeState(30+hand)  -- Craft kneeling w/ appropriate tool out
	player:ChangeMusic(73)
	callClientFunction(player, "delegateCommand", craftJudge, "openCraftProgressWidget", commandactor, startDur, startQly, startHq)

	while true do
		local progDiff = math.random(30,50)
		local duraDiff = math.random(1,3)
		local qltyDiff = math.random(0,2)

		if progress >= 100 then
			callClientFunction(player, "delegateCommand", craftJudge, "closeCraftProgressWidget", commandactor)

			-- Local leve crafts aren't offered yet (see getCraftQuest), so this is always a normal synth.
			-- "You create <#3 quantity> <#1 item> <#2 quality>." The client wants item, quality, quantity,
			-- crafter.
			player:SendGameMessage(GetWorldMaster(), 40111, 0x20, recipe.resultItemID, 1, recipe.resultQuantity, player)
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(recipe.resultItemID, recipe.resultQuantity, 1)
			player:AddRecentRecipe(recipe)
			break
		end

		choice = callClientFunction(player, "delegateCommand", craftJudge, "craftCommandUI", commandactor, 29, 2, 29530,29531,29532,29533,29534)

		if choice then

			if skillAnim[choice] then
				player:PlayAnimation(skillAnim[choice])
			end

			wait(3)

			player:SendGameMessage(worldMaster, 40108, 0x20, choice,2)

			if choice ~= 29531 then
				progress = progress + progDiff

				if progress >= 100 then
					progress = 100
				end

				startDur = startDur - duraDiff
				startQly = startQly + qltyDiff

				player:SendGameMessage(worldMaster, 40102, 0x20, progDiff)
				player:SendGameMessage(worldMaster, 40103, 0x20, duraDiff)
				player:SendGameMessage(worldMaster, 40104, 0x20, qltyDiff)
			end
			callClientFunction(player, "delegateCommand", craftJudge, "updateInfo", commandactor, progress, startDur, startQly, nil, nil, nil, nil, nil)

		end
	end
end