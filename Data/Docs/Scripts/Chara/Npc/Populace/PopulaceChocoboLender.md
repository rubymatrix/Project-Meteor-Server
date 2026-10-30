# PopulaceChocoboLender: chocobo lender

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceChocoboLender.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceChocoboLender.lua)

Client functions:

- `eventTalkWelcome(player)`: opening line.
- `eventAskMainMenu(player, curLevel, hasFundsForRent, isPresentChocoboIssuance, isSummonMyChocobo, isChangeBarding, currentChocoboWare)`: main menu.
- `eventTalkMyChocobo(player)`: cutscene for getting a chocobo.
- `eventSetChocoboName(true)`: name dialog.
- `eventAfterChocoboName(player)`: after naming; plays the cutscene, returns state and waits to
  teleport outside the city.
- `eventCancelChocoboName(player)`: naming cancelled; returns state.
- `eventTalkStepBreak(player)`: ends the talk turn with a goodbye.

Notes:

- Rent price and time look hardcoded in the client: always 800 gil for 10 minutes.
- `eventSetChocoboName` needs the actor with id `1080101` present in the client instance, or the
  client crashes.
- Getting or renting a chocobo needs special spawn codes to work.
