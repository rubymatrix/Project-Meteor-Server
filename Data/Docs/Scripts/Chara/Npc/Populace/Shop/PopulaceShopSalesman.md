# PopulaceShopSalesman: shop vendors

Script: [`Data/scripts/Chara/Npc/Populace/Shop/PopulaceShopSalesman.lua`](../../../../../../scripts/Chara/Npc/Populace/Shop/PopulaceShopSalesman.lua)

Client functions:

- `welcomeTalk(sheetId, player)`: Start Message
- `selectMode(askMode)`: Shows buy/sell modes. If askmode > 0 show guild tutorial. If askmode == -7/-8/-9 show nothing. Else show affinity/condition tutorials.
- `selectModeOfClassVendor()`: Opens categories for class weapons and gear
- `selectModeOfMultiWeaponVendor(consumptionmenuId)`: Opens categories for weapons/tools (war/magic/land/hand). Arg consumptionmenuId appends location of item repair person. -1: Ul'dah, -2: Gridania, -3: Limsa
- `selectModeOfMultiArmorVendor(consumptionmenuId)`: Opens categories for armor in different slots. Arg consumptionmenuId appends location of item repair person. -1: Ul'dah, -2: Gridania, -3: Limsa
- `openShopBuy(player, shopPack, CurrencyItemId)`: ShopPack: Items to appear in window. CurrencyItemId: What is being used to buy these items.
- `selectShopBuy(player)`: Call after openShopBuy() to open widget
- `closeShopBuy(player)`: Closes the buy window
- `openShopSell(player)`: Call this to open sell window
- `selectShopSell(player)`: Call after openShopSell()
- `closeShopSell(player)`: Closes the sell window
- `confirmSellingItem(itemId, quality, quantity, gil)`: Simple Sell confirmation window
- `selectFacility(?, sheetId, 3)`: Opens the facility chooser.
- `confirmUseFacility(player, cost)`: Facility cost confirm
- `informSellPrice(1, chosenItem, price)`: Shows sell confirm window. ChosenItem must be correct.
- `startTutorial(nil, menuId)`: Opens up a tutorial menu for each guild type based on menuId
- `finishTalkTurn()`: Done at the end.
