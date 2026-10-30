# PopulaceFlyingShip: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceFlyingShip.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceFlyingShip.lua).

Client event functions:

- `eventIn(player, hasTicket, nil?, travelPrice)`: If hasTicket == nil, say no money text.
- `eventOut(isAborting)`: Set isAborting to 30010 if player didn't "use" the airship. Shows no refund warning.
- `eventNG(player)`: Message said when player is talking to the wrong npc.
