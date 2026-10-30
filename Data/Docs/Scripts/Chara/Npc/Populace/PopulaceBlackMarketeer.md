# PopulaceBlackMarketeer: Grand Company black marketeers

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceBlackMarketeer.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceBlackMarketeer.lua)

The class applies to three NPCs:

| Class id | NPC | City |
|---|---|---|
| 1500293 | Momoroon | Limsa Lominsa |
| 1500294 | Gagaroon | Gridania |
| 1500295 | Lalaroon | Ul'dah |

## Client functions

```
eventTalkWelcome(player)                        - Start text
eventSellItemAsk(player, itemName, tradePrice)  - Requires GC affiliation. Trade menu for the Commemorative Coin
eventAskMainMenu(player, index)                 - Menu prompt to buy with gil or with GC seals
eventTalkBye(player)                            - Bye text
eventTalkStepBreak()                            - Ends talk; the NPC turns back to its original facing

eventSealShopMenuOpen()                         - Opens the seal shop menu
eventSealShopMenuAsk()                          - Returns two values: one that seems always true, and the index of the item bought
eventSealShopMenuClose()                        - Closes the seal menu
eventGilShopMenuOpen()                          - Opens the gil shop menu
eventGilShopMenuAsk()                           - Returns two values: one that seems always true, and the index of the item bought
eventGilShopMenuClose()                         - Closes the gil menu
```
