# RetainerFurniture: client event functions

Script: [`Data/scripts/Chara/Npc/Object/RetainerFurniture.lua`](../../../../../scripts/Chara/Npc/Object/RetainerFurniture.lua)

- `eventPushStepOpenRetainerMenu()`: open the menu to choose a retainer.
- `eventRingBell()`: play the bell ring animation.
- `eventPushRetainerCallCaution()`: warn that an open bazaar will close if a retainer is chosen.
- `eventTalkRetainerMenu(hasPossessions, showDispatchChoice)`: open the retainer menu.
- `eventTalkRetainerDismissal(hasPossessions)`: show the dismiss confirmation.
- `eventTalkRetainerMannequin(0 enable / 1 disable)`: dialog to enable or disable modeling.
- `eventTalkRetainerItemTrade(operationCode)`: operate RetainerTradeWidget. 1 open, 2 select mode, 3 close.
- `eventTalkRetainerItemList(operationCode)`: operate the bazaar widget. 1 open, 2 select mode, 3 close.
- `eventReturnResult(resultCode, ?)`: redraw the RetainerTrade UI.
- `eventTalkSelectBazaarStreet(limitsWardChoices)`: dialog to send a retainer to a street. Set to 20.
- `eventTalkFinish()`: end the talk with the retainer.
- `eventPlayerTurn(rotation)`: turn the player.
