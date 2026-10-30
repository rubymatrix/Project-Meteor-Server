# TradeExecuteCommand: player trades

Script: [`Data/scripts/Command/TradeExecuteCommand.lua`](../../../scripts/Command/TradeExecuteCommand.lua)

## Client functions

```
processTradeCommandOpenTray()             - Opens the trade widget
processTradeCommandCloseTray()            - Closes the trade widget
processTradeCommandReply(command, params) - Operates the trade widget
processUpdateTradeCommandTrayData()       - ?
```

## Widget commands

```
set:       resets the widget to "Set Mode" (on once an item is selected while waiting for a reply)
back:      resets the widget to "Choose Mode" (on when the UI operation is done)
fix:       you have accepted the deal
targetfix: the target has accepted the deal
doedit:    you have cancelled your accept
reedit:    the target has cancelled their accept
```
