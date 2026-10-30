# OrdinaryRetainer: summoned retainer

Script: [`Data/scripts/Chara/Npc/Retainer/OrdinaryRetainer.lua`](../../../../../scripts/Chara/Npc/Retainer/OrdinaryRetainer.lua)

Client functions:

- `eventTalkRetainerOther()`
- `eventTalkRetainerMenu(mode, hasPossessions)`: main menu. Mode 2 hides the dismiss option.
- `eventTalkRetainerDismissal(hasPossessions)`: dismiss confirmation.
- `eventTalkRetainerMannequin(0 enable / 1 disable confirm)`: bazaar modeling confirmation.
- `eventTalkRetainerItemTrade(operationCode)`: drives RetainerTradeWidget. 1 open, 2 select mode,
  3 close.
- `eventTalkRetainerItemList(operationCode)`: drives the bazaar widget. 1 open, 2 select mode,
  3 close.
- `eventReturnResult(resultCode, ?)`: redraws the RetainerTrade UI.
- `sayToPlayer(actorClassId, messageType, argument)`: the retainer says a phrase to the player.
- `eventTalkFinish()`: the NPC stops looking at the player.
- `eventPlayerTurn(angle)`: turns the player to the angle.
