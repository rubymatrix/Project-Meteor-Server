# StoryRaid: Grand Company story raids

Script: [`Data/scripts/Content/InstanceRaid/StoryRaid.lua`](../../../../scripts/Content/InstanceRaid/StoryRaid.lua)

The Grand Company story raids: the Howling Eye (Garuda), the Castrum Novum transmission tower and
Rivenroad (Nael van Darnus). Each client director's file picks its variant. The fights are stand-ins
until the real ones are built: a boss and two adds from existing pools, no mechanics, won when all
three are down.

## Story half

The Lesser Ifrit director shares the story half: `StoryRaid.begin` brings the starter's party in, and
`StoryRaid.onEnd` calls each participant's quest `onRaidCleared(player, quest, director, bonus)` on a
win and puts everyone back outside.

Story fields:

- `quests`: the quest id suffix the three company versions share.
- `bonus`: `"company"` (the whole party in the player's company) or `"allCompanies"` (all three in
  the party).
- `exit = { zone, at = { x, y, z, rot } }`.
