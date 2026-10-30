require("Global")

--[[
Handles all trading between players: opens the trade widget and runs its commands until the deal
closes. Client functions and widget commands: Data/Docs/Scripts/Command/TradeExecuteCommand.md.
--]]

function onEventStarted(player, actor, eventType, eventName)
	local itemSlot

	callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandOpenTray")

	local tradeOffering = player:GetTradeOfferings()

	while true do
		widgetOpen, chosenOperation, tradeSlot, itemActor, quantity, itemPackageId, itemSlot = callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processUpdateTradeCommandTrayData")

		--Abort script if client script dead
		if widgetOpen == false or widgetOpen == nil then
			player:FinishTradeTransaction()
			break
		end

		--Handle you/target canceling/finishing the trade
		if not player:IsTrading() or not player:GetOtherTrader():IsTrading() then
			player:FinishTradeTransaction()
			break
		end

		--Handle target accepting
		if player:GetOtherTrader():IsTradeAccepted() == true then
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "targetfix")
		else
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "reedit")
		end

		--Check if both accepted the trade
		if player:IsTradeAccepted() and player:GetOtherTrader():IsTradeAccepted() then
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandCloseTray")
			GetWorldManager():CompleteTrade(player, player:GetOtherTrader())
			break
		end

		--Clear Item
		if chosenOperation == 1 then
			player:RemoveTradeItem(tradeSlot - 1)
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "set")
		--Clear All
		elseif chosenOperation == 2 then
			player:ClearTradeItems()
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "set")
		--Item Chosen
		elseif chosenOperation == 3 then
			player:AddTradeItem(tradeSlot - 1, itemActor, quantity)
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "set", 2, 2, 2, 2)
		--Gil Chosen
		elseif chosenOperation == 4 then
			player:AddTradeItem(tradeSlot - 1, itemActor, quantity)
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "set")
		--Cancel
		elseif chosenOperation == 11 then
			player:FinishTradeTransaction()
			break
		--OK
		elseif chosenOperation == 12 then
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "fix")
			player:AcceptTrade(true)
		--Reedit
		elseif chosenOperation == 13 then
			callClientFunction(player, "delegateCommand", GetStaticActor("TradeExecuteCommand"), "processTradeCommandReply", "doedit")
			player:AcceptTrade(false)
		end

		wait(1)
	end

	player:EndEvent()

end