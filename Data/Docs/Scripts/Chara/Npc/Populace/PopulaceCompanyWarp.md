# PopulaceCompanyWarp: Grand Company aethernet warps

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCompanyWarp.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCompanyWarp.lua)

Client functions:

- `eventTalkWelcome(player)`: opening line.
- `eventAskMainMenu(player, index)`: teleport menu. Hides the point at `index` so you can't warp
  to where you stand.
- `eventAfterWarpOtherZone(player)`: fades out for the warp.
- `eventTalkStepBreak()`: holds the client up; purpose unknown.
