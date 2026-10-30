# Opening: opening battles

Script: [`Data/scripts/Content/Quest/Opening.lua`](../../../../scripts/Content/Quest/Opening.lua)

Opening battles of the three starting cities (directors QuestDirectorMan0g001, Man0l001, Man0u001).

- g: Papalymo and Yda against three wolves.
- l: Y'shtola and Sthalmann against three aurelias on the deck.
- u: Niellefresne and Thancred against a goobbue.

Foes stand still until hit. Allies close in when the player draws and strike after the first hit.
The rest of the pack goes to the tank unclaimed (orange); the foe hit turns to the tank after
`TANK_PULL_SECONDS`. When a foe dies, allies go straight to the next so they stay in battle stance.
The tank only swings; casters use single-target spells so they never hit foes nobody pulled.
Won when the foes are dead.
